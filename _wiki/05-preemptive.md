# 05-Preemptive

## 概述

這是 mini-riscv-os 的第五個階段，實現完整的搶先式多任務 (Preemptive Multitasking) 系統。搶先式多任務是現代作業系統的核心特徵，它允許作業系統在任何時刻強制搶佔正在運行的任務，將 CPU 控制權轉交給其他任務。這與第三階段的合作式多任務形成鮮明對比。

本階段的關鍵在於將定時器中斷與任務管理結合：當定時器中斷發生時，作業系統不僅處理中斷，還會執行上下文切換，強行將 CPU 從當前任務手中奪走，分配給下一個任務。

## 合作式 vs 搶先式多任務

### 合作式多任務的回顧

在第三階段實現的合作式多任務中：
- 任務必須主動呼叫 `task_os()` 放棄 CPU 控制權
- 如果某個任務沒有呼叫 `task_os()`，它會一直執行下去
- 系統的穩定性依賴於每個任務的自覺配合

這種方式的問題：
1. 一個有 bug 的任務（如無意中的無窮迴圈）會導致整個系統掛起
2. 無法確保所有任務都能公平地獲得 CPU 時間
3. 系統響應性差，無法及時處理緊急事件

### 搶先式多任務的優勢

搶先式多任務解決了上述問題：
1. **強制切換**: 作業系統透過定時器中斷強制奪取 CPU 控制權
2. **公平調度**: 每個任務都能獲得固定的時間片
3. **即時響應**: 系統可以及時響應外部事件
4. **容錯性**: 即使某個任務出現問題，系統仍能繼續運行

### 兩種方式的比較

| 特性 | 合作式 | 搶先式 |
|------|--------|--------|
| 切換時機 | 任務主動呼叫 | 定時器中斷 |
| CPU 公平性 | 取決於任務配合 | 作業系統保障 |
| 響應速度 | 不可預測 | 可預測 |
| 實現複雜度 | 較低 | 較高 |
| 穩定性 | 一個任務出錯會影響全系統 | 某任務出錯不影響其他任務 |

## 搶先式排程的實現原理

### 時間片 (Time Slice)

時間片是每個任務連續執行的最大時間：
- 例如：設定時間片為 10ms，則每個任務最多執行 10ms
- 時間片用完後，作業系統強制切換到下一個任務

在本專案中，定時器中斷的間隔就是時間片：
```c
#define interval 10000000  // 大約 1 秒
```

實際上這個間隔比較長（1秒），是因為我們還沒有完整實現上下文保護機制。真正的搶先式系統通常使用更短的時間片（如 10ms）。

### 中斷觸發的上下文切換

當定時器中斷發生時的處理流程：

1. **中斷發生**: CPU 完成目前指令的執行後，跳轉到 mtvec 指定的處理常式
2. **保存上下文**: 保存當前任務的完整狀態（包括程式計數器）
3. **處理中斷**: 調用定時器處理常式，更新計數器和定時器
4. **調度決策**: 選擇下一個要執行的任務
5. **上下文切換**: 恢復下一個任務的狀態
6. **返回**: 使用 mret 返回到新任務繼續執行

這與合作式多任務有本質區別：
- 合作式：用戶任務主動呼叫切換
- 搶先式：中斷發生時強制切換，用戶任務可能完全不知道

## 程式碼實現

### timer.c - 定時器中斷處理

```c
#include "timer.h"

#define interval 10000000

void timer_init() {
    int id = r_mhartid();
    
    *(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
    
    w_mtvec((reg_t)sys_timer);
    w_mstatus(r_mstatus() | MSTATUS_MIE);
    w_mie(r_mie() | MIE_MTIE);
}

static int timer_count = 0;

void timer_handler() {
    // 禁用定時器中斷，避免嵌套
    w_mie(~((~r_mie()) | (1 << 7)));
    
    lib_printf("timer_handler: %d\n", ++timer_count);
    
    int id = r_mhartid();
    *(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
    
    // 關鍵：在定時器中斷時返回 OS，而不是繼續執行任務
    task_os();
    
    // 重新啟用定時器中斷
    w_mie(r_mie() | MIE_MTIE);
}
```

關鍵改變：在 `timer_handler()` 的最後，我們調用 `task_os()` 來觸發任務切換。這是中斷驅動的任務切換的核心。

### sys.s - 中斷處理入口

```assembly
.align 4
.global sys_timer

sys_timer:
    # 保存上下文到目前任務
    # 由於我們在 C 函式中處理，這裡只是簡單的跳轉
    
    # 調用 C 語言處理常式
    call timer_handler
    
    # 這個 ret 不會執行到，因為 timer_handler 會切換任務
    # 但如果任務返回，會返回到這裡
    mret
```

### os.c - 排程主迴圈

```c
void os_kernel() {
    task_os();
}

void os_start() {
    lib_puts("OS start\n");
    user_init();      // 初始化使用者任務
    timer_init();     // 啟動定時器中斷
}

int os_main(void) {
    os_start();
    
    int current_task = 0;
    while (1) {
        lib_puts("OS: Activate next task\n");
        task_go(current_task);  // 切換到任務執行
        lib_puts("OS: Back to OS\n");
        current_task = (current_task + 1) % taskTop;
        lib_puts("\n");
    }
    return 0;
}
```

這段程式碼與第三階段類似，但現在：
- `timer_init()` 啟動了定時器中斷
- 每當定時器中斷發生，會強行切換任務
- 不再依賴用戶任務主動呼叫 `task_os()`

### user.c - 使用者任務

```c
int task0_count = 0;
int task1_count = 0;

void user_task0(void) {
    lib_puts("Task0: Created!\n");
    while (1) {
        lib_printf("Task0: Running..., count=%d\n", ++task0_count);
        lib_delay(1000);  // 簡單的延遲
    }
}

void user_task1(void) {
    lib_puts("Task1: Created!\n");
    while (1) {
        lib_printf("Task1: Running..., count=%d\n", ++task1_count);
        lib_delay(1000);
    }
}

void user_init() {
    task_create(&user_task0);
    task_create(&user_task1);
}
```

注意：用戶任務現在**不需要**呼叫 `task_os()`！任務可以一直執行到時間片用完。

## 執行流程詳細分析

### 系統啟動階段

1. `os_main()` 調用 `os_start()`
2. `os_start()` 調用 `user_init()`，創建 Task0 和 Task1
3. `os_start()` 調用 `timer_init()`，啟動定時器中斷
4. 定時器開始遞增計數

### 第一次任務執行

1. `os_main()` 調用 `task_go(0)`，切換到 Task0
2. Task0 開始執行，輸出 "Task0: Created!"
3. Task0 進入無窮迴圈，輸出 "Task0: Running..., count=1"
4. Task0 執行 `lib_delay(1000)`（此時任務仍在用戶模式）

### 定時器中斷發生

1. 定時器中斷觸發（經過 interval 週期）
2. CPU 跳轉到 `sys_timer`（mtvec 設置的地址）
3. 調用 `timer_handler()`
4. `timer_handler()` 輸出 "timer_handler: 1"
5. `timer_handler()` 重新設置定時器
6. **關鍵**: `timer_handler()` 調用 `task_os()`

### 上下文切換

1. `task_os()` 保存 Task0 上下文到 `ctx_tasks[0]`
2. `task_os()` 切換到 OS 上下文 (`ctx_os`)
3. 控制權返回到 `os_main()` 的 while 迴圈
4. 輸出 "OS: Back to OS"

### 選擇下一個任務

1. `current_task = (0 + 1) % 2 = 1`
2. 調用 `task_go(1)`，切換到 Task1
3. Task1 執行並輸出

### 迴圈繼續

1. Task1 執行期間，定時器中斷再次發生
2. `timer_handler()` 調用 `task_os()`
3. 控制權返回 OS，選擇下一個任務 (Task0)
4. 迴圈繼續，實現時間片輪詢

## 執行範例輸出

```
OS start
OS: Activate next task
Task0: Created!
Task0: Now, return to kernel mode
OS: Back to OS

OS: Activate next task
Task1: Created!
Task1: Now, return to kernel mode
OS: Back to OS

OS: Activate next task
Task0: Running...
Task0: Running...
Task0: Running...
timer_handler: 1
OS: Back to OS

OS: Activate next task
Task1: Running...
Task1: Running...
Task1: Running...
timer_handler: 2
OS: Back to OS

OS: Activate next task
Task0: Running...
Task0: Running...
Task0: Running...
timer_handler: 3
OS: Back to OS
...
```

注意觀察：
- Task0 和 Task1 各自連續執行 3 次後被中斷
- 這是因為 `lib_delay(1000)` 需要時間，而定時器中斷間隔較長
- 這展示了時間片輪詢的效果

## 重要概念まとめ

### 1. 搶先式排程的優勢

**公平性**: 所有任務都能獲得 CPU 時間，不會被單個任務壟斷

**響應性**: 系統可以及時響應外部事件和中斷

**穩定性**: 一個任務出錯不會導致整個系統崩潰

**生產力**: CPU 資源得到更好的利用

### 2. 時間片的大小

時間片的選擇是一個權衡：
- **太短**: 上下文切換開銷大，CPU 浪費在切換上
- **太長**: 響應時間差，用戶體驗不好

典型的桌面系統：10-20ms
即時系統：可能更短（微秒級）
本專案：較長（約 1 秒），因為教學需要明顯可見的效果

### 3. 上下文保存的完整性

在真正的搶先式系統中，上下文保存必須完整：
- 所有通用暫存器
- 浮點暫存器（如果使用）
- 程式計數器（透過 mepc）
- 狀態暫存器

本專案簡化了這個過程，專注於核心概念。

### 4. 中斷與任務調度的關係

中斷是搶先式排程的觸發器：
- 中斷發生 → 保存當前狀態 → 選擇新任務 → 恢復新狀態

這是中斷驅動程式設計的一個典型應用。

### 5. 任務狀態機

在搶先式多任務中，任務有以下狀態：

| 狀態 | 描述 |
|------|------|
| Running | 正在 CPU 上執行 |
| Ready | 準備好執行，等待被調度 |
| Blocked | 等待某個事件（如 I/O） |
| Terminated | 任務結束 |

狀態轉換：
- Running → Ready：時間片用完
- Running → Blocked：等待 I/O
- Ready → Running：被調度器選擇
- Blocked → Ready：事件發生

## 與真實 OS 的比較

Linux、Windows 等現代作業系統的搶先式排程更加複雜：

| 特性 | 本專案 | 真實 OS |
|------|--------|---------|
| 時間片 | 固定 | 動態調整 |
| 優先級 | 平等 | 多級優先級 |
| 上下文保存 | 最小集合 | 完整保存 |
| 任務阻塞 | 不支持 | 支持 I/O 阻塞 |
| 虛擬記憶體 | 不支持 | 支持 |

## 下一步

下一課 [[06-Mutex]] 將介紹互斥鎖 (Mutex)，這是解決搶先式多任務中共享資源競爭問題的基本同步機制。

## 相關資源

- 搶先式多任務維基百科: https://en.wikipedia.org/wiki/Preemptive_multitasking
- RISC-V 搶先式內核: https://github.com/mit-pdos/xv6-riscv
- 作業系統排程: https://en.wikipedia.org/wiki/Scheduling_(computing)
