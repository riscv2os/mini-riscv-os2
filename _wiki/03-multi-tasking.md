# 03-Multi-Tasking

## 概述

這是 mini-riscv-os 的第三個階段，在第二階段上下文切換的基礎上，實現完整的多任務管理系統。本階段引入任務控制區 (Task Control Block, TCB) 的概念，並實現任務創建、任務排程、以及合作式多任務的核心功能。

合作式多任務 (Cooperative Multitasking) 是一種多任務策略，任務自願放棄 CPU 控制權給其他任務使用。這與搶先式多任務 (Preemptive Multitasking) 不同，後者由作業系統定時強制切換任務。

## 合作式多任務的原理

### 為什麼叫做「合作式」？

在合作式多任務中，每個任務必須「合作」才能實現多任務效果。具體來說：
- 每個任務在適當時機主動呼叫 `task_os()` 或类似的函数来放棄 CPU 控制權
- 如果某個任務沒有放棄控制權，它會一直執行下去，阻止其他任務執行
- 這依賴於程式設計師的自覺性和良好的編程習慣

### 合作式 vs 搶先式

| 特性 | 合作式多任務 | 搶先式多任務 |
|------|-------------|-------------|
| 任務切換時機 | 任務主動放棄 | 作業系統定時強制 |
| 即時性 | 低（取決於任務配合） | 高（由定時器控制） |
| 系統複雜度 | 較低 | 較高 |
| 響應時間 | 不確定 | 可預測 |
| 適用場景 | 簡單嵌入式系統 | 需要即時反應的系統 |

### 優點與缺點

**優點**：
- 實現相對簡單
- 不需要硬體定時器中斷支援
- 任務程式碼易於理解（總是執行到完成才讓出 CPU）
- 沒有競爭條件（因為一次只有一個任務執行）

**缺點**：
- 一個任務死循環會導致整個系統停頓
- 無法充分利用 CPU 時間
- 即時響應性差

## 任務控制區 (TCB) 設計

### task.h - 任務頭文件

```c
#ifndef __TASK_H__
#define __TASK_H__

#include "riscv.h"
#include "sys.h"

#define MAX_TASK 10      // 最大任務數量
#define STACK_SIZE 1024  // 每個任務的堆疊大小

extern int taskTop;     // 當前任務數量

// 任務創建
extern int task_create(void (*task)(void));
// 啟動任務
extern void task_go(int i);
// 任務返回 OS
extern void task_os();

#endif
```

### task.c - 任務管理實現

```c
#include "task.h"
#include "lib.h"

// 任務堆疊陣列
uint8_t task_stack[MAX_TASK][STACK_SIZE];

// OS 上下文
struct context ctx_os;
// 任務上下文陣列
struct context ctx_tasks[MAX_TASK];
// 目前正在執行的上下文指標
struct context *ctx_now;
// 目前任務數量
int taskTop = 0;
```

### 任務創建 - task_create()

```c
int task_create(void (*task)(void)) {
    int i = taskTop++;  // 分配新的任務 ID
    
    // 初始化任務上下文
    ctx_tasks[i].ra = (reg_t) task;  // 設置任務入口點（返回位址）
    ctx_tasks[i].sp = (reg_t) &task_stack[i][STACK_SIZE - 1];  // 設置堆疊頂端
    
    return i;
}
```

任務創建過程非常簡單：
1. 分配一個任務 ID
2. 將任務函式位址設置為「返回位址」
3. 分配並初始化任務堆疊

### 啟動任務 - task_go()

```c
void task_go(int i) {
    ctx_now = &ctx_tasks[i];     // 記錄目前任務
    sys_switch(&ctx_os, &ctx_now);  // 切換到任務
}
```

這裡的關鍵是：
- `ctx_now` 指向即將執行的任務上下文
- 調用 `sys_switch` 切換到該任務

### 任務返回 OS - task_os()

```c
void task_os() {
    struct context *ctx = ctx_now;   // 保存目前任務的上下文
    ctx_now = &ctx_os;                // 切換到 OS 上下文
    sys_switch(ctx, &ctx_os);         // 切換回 OS
}
```

這是任務主動放棄 CPU 控制權的方式。任務呼叫 `task_os()` 後：
1. 目前的任務上下文被保存
2. 切換回 OS 上下文
3. 控制權返回到 OS 的排程迴圈

## os.c - 核心排程器

### os_kernel() - OS 內核入口

```c
void os_kernel() {
    task_os();  // 這裡不會返回，除非發生上下文切換
}
```

這是一個包裝函式，未來可能會在這裡添加更多內核邏輯。

### os_start() - 初始化函式

```c
void os_start() {
    lib_puts("OS start\n");
    user_init();  // 呼叫使用者初始化函式，創建任務
}
```

### os_main() - 主迴圈

```c
int os_main(void) {
    os_start();  // 初始化
    
    int current_task = 0;
    while (1) {
        lib_puts("OS: Activate next task\n");
        task_go(current_task);  // 啟動任務執行
        lib_puts("OS: Back to OS\n");
        current_task = (current_task + 1) % taskTop;  // Round-Robin 排程
        lib_puts("\n");
    }
    return 0;
}
```

這是一個典型的合作式多任務排程器：
1. 使用 Round-Robin 演算法選擇下一個任務
2. 啟動任務執行
3. 任務執行完（呼叫 task_os）後，選擇下一個任務
4. 重複迴圈

### Round-Robin 排程

Round-Robin 是一種簡單的排程演算法：
- 每個任務分配一個時間片
- 任務依序輪流執行
- 當前任務執行完後，選擇下一個任務
- 所有任務都執行過後，從頭開始

公式：`next_task = (current_task + 1) % taskTop`

## user.c - 使用者任務

### 任務0

```c
void user_task0(void) {
    lib_puts("Task0: Created!\n");
    while (1) {
        lib_puts("Task0: Running...\n");
        task_os();  // 主動放棄 CPU 控制權
    }
}
```

### 任務1

```c
void user_task1(void) {
    lib_puts("Task1: Created!\n");
    while (1) {
        lib_puts("Task1: Running...\n");
        task_os();  // 主動放棄 CPU 控制權
    }
}
```

### 初始化函式

```c
void user_init() {
    task_create(&user_task0);
    task_create(&user_task1);
}
```

## 執行流程詳細分析

### 系統啟動

1. QEMU 載入 os.elf，CPU 開始執行 `_start`
2. `_start` 初始化堆疊，檢查 hartid
3. hart 0 跳轉到 `os_main()`

### 第一階段：任務初始化

1. `os_main()` 呼叫 `os_start()`
2. `os_start()` 呼叫 `user_init()`
3. `user_init()` 呼叫兩次 `task_create()`
4. `task_create()` 初始化兩個任務的上下文 (ra, sp)

### 第二階段：任務執行迴圈

1. `os_main()` 設定 `current_task = 0`
2. 呼叫 `task_go(0)`:
   - `ctx_now = &ctx_tasks[0]`
   - `sys_switch(&ctx_os, &ctx_tasks[0])`
3. 組合語言保存 OS 上下文到 `ctx_os`
4. 組合語言恢復 Task0 上下文
5. 執行 `ret`，跳轉到 Task0 函式

### 第三階段：Task0 執行

1. Task0 輸出 "Task0: Created!"
2. 進入無窮迴圈
3. 輸出 "Task0: Running..."
4. 呼叫 `task_os()`

### 第四階段：返回 OS

1. `task_os()` 保存 Task0 上下文到 `ctx_tasks[0]`
2. 切換回 OS 上下文 (`ctx_os`)
3. `os_main()` 收到控制權
4. 輸出 "OS: Back to OS"
5. 計算下一個任務：`current_task = (0 + 1) % 2 = 1`

### 第五階段：切換到 Task1

1. 呼叫 `task_go(1)`
2. 切換到 Task1
3. Task1 執行並返回 OS
4. 迴圈繼續

## 編譯與執行

### 編譯指令

```sh
make clean
make
```

### 執行指令

```sh
make qemu
```

### 預期輸出

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
OS: Back to OS

OS: Activate next task
Task1: Running...
OS: Back to OS

OS: Activate next task
Task0: Running...
OS: Back to OS

...
```

## 重要概念まとめ

### 1. 任務的狀態

在合作式多任務中，任務有兩種狀態：
- **執行中 (Running)**: 目前正在 CPU 上執行
- **就緒 (Ready)**: 可以執行，等待被 OS 調度

當任務呼叫 `task_os()` 時，它從「執行中」變為「就緒」，OS 選擇下一個任務執行。

### 2. 任務 vs 執行緒

在傳統作業系統術語中：
- **Process (行程)**: 獨立的位址空間，資源保護的基本單位
- **Thread (執行緒)**: 共享同一個行程的資源，CPU 調度的基本單位

本專案實現的是**執行緒**（或稱為「輕量級行程」），因為所有任務共享同一個位址空間，沒有記憶體保護。

### 3. 靜態 vs 動態任務創建

本階段的任務是**靜態**創建的：
- 任務數量在編譯時就確定了 (`MAX_TASK = 10`)
- 任務函式指標在編譯時就確定了

動態任務創建允許在執行時創建新任務，需要記憶體配置和更復雜的任務管理。

### 4. 任務優先順序

本階段使用簡單的 Round-Robin 排程，沒有優先順序。未來可以擴展為：
- 固定優先順序排程
- 動態優先順序調整
- 時間片輪詢

### 5. 合作式的局限性

注意任務的 `task_os()` 呼叫位置：
- 如果任務沒有呼叫 `task_os()`，其他任務永遠無法執行
- 在實際應用中，需要確保每個任務都會定期讓出 CPU

## 下一步

下一課 [[04-Timer-Interrupt]] 將介紹定時器中斷，這是實現搶先式多任務的第一步。通过定时器中断，系统可以强制切换任务，不再依赖任务的主动配合。

## 相關資源

- 合作式多任務維基百科: https://en.wikipedia.org/wiki/Cooperative_multitasking
- Round-Robin 排程: https://en.wikipedia.org/wiki/Round-robin_scheduling
- xv6 task management: https://github.com/mit-pdos/xv6-riscv
