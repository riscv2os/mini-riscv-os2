# 09-Interrupt-ISR

## 概述

這是 mini-riscv-os 的第九個階段，也是最後一個階段，實現完整的中斷服務常式 (Interrupt Service Routine, ISR) 註冊和分發系統。中斷是作業系統與硬體互動的基礎機制，幾乎所有的 I/O 裝置都透過中斷與 CPU 通訊。本階段建立一個通用的 ISR 框架，允許任務在執行時動態註冊中斷處理常式，這是構建現代作業系統驅動程式的關鍵基礎。

在前面的階段中，我們已經實現了定時器中斷，但那是硬編碼在系統中的。本階段將實現：
- ISR 表格：用於儲存中斷處理常式的映射關係
- 動態註冊：允許在執行時註冊新的 ISR
- 分發機制：根據中斷編號分發到對應的處理常式

## 中斷服務常式的基礎概念

### 什麼是中斷？

中斷 (Interrupt) 是硬體通知 CPU 有重要事件發生的機制：
- **定時器中斷**：告知 CPU 硬體定時器已到期
- **UART 中斷**：告知 CPU 有資料到达或發送完成
- **磁碟中斷**：告知 CPU 磁碟 I/O 完成
- **網路中斷**：告知 CPU 網路資料已接收

中斷允許 CPU 不需要持續輪詢 I/O 狀態，而是在有事件發生時才處理，大大提高了系統的效率和即時性。

### ISR 與異常的區別

在 RISC-V 架構中，陷阱 (Trap) 分為兩類：

1. **中斷 (Interrupt)**：異步事件，由外部觸發
   - 軟體中斷
   - 定時器中斷
   - 外部中斷

2. **異常 (Exception)**：同步事件，由指令執行觸發
   - 存取違規
   - 非法指令
   - 系統呼叫

兩者都透過相同的機制處理：CPU 跳轉到 mtvec 指定的位址，保存目前的執行狀態，然後執行處理常式。

### 中斷編號

RISC-V 中的中斷透過 IRQ 編號識別：

| IRQ 編號 | 中斷類型 |
|----------|----------|
| 0-7 | Machine 模式下保留 |
| 8-15 | Supervisor 模式下使用 |
| 16-23 | User 模式下使用 |

在本專案中，我們使用 0-15 的 IRQ 編號來註冊自定義的 ISR。

## ISR 框架的實現

### isr.h - ISR 頭文件

```c
#ifndef __ISR_H__
#define __ISR_H__

#include "riscv.h"

#define MAX_ISR 16  // 最大支援的中斷數量

// ISR 處理函式類型
typedef void (*isr_handler_t)(void);

// ISR 表格項目
typedef struct {
    int irq;              // 中斷編號
    isr_handler_t handler; // 處理函式指標
} isr_entry_t;

// 初始化 ISR 系統
void isr_init();
// 註冊 ISR
int isr_register(int irq, isr_handler_t handler);
// 分發 ISR
void isr_dispatch(int irq);

#endif
```

### isr.c - ISR 實現

```c
#include "isr.h"

// ISR 表格
static isr_entry_t isr_table[MAX_ISR];
static int isr_count = 0;

// 初始化 ISR 表格
void isr_init() {
    for (int i = 0; i < MAX_ISR; i++) {
        isr_table[i].irq = -1;
        isr_table[i].handler = 0;
    }
    isr_count = 0;
}
```

這段程式碼初始化 ISR 表格，將所有條目的 irq 設為 -1（表示未使用），handler 設為 0（空指標）。

### 動態註冊 ISR

```c
int isr_register(int irq, isr_handler_t handler) {
    // 檢查 IRQ 編號是否有效
    if (irq < 0 || irq >= MAX_ISR) {
        return -1;  // 無效的 IRQ 編號
    }
    
    // 註冊 ISR 到表格
    isr_table[irq].irq = irq;
    isr_table[irq].handler = handler;
    
    return 0;  // 成功
}
```

這個函式允許任務在執行時註冊自己的中斷處理常式。參數包括：
- irq：中斷編號 (0-15)
- handler：處理函式的指標

### ISR 分發機制

```c
void isr_dispatch(int irq) {
    // 檢查 IRQ 編號是否有效
    if (irq >= 0 && irq < MAX_ISR) {
        // 檢查是否有註冊的處理常式
        if (isr_table[irq].handler != 0) {
            // 調用處理常式
            isr_table[irq].handler();
        }
    }
}
```

當中斷發生時，系統會調用 isr_dispatch，傳入中斷編號。分發機制會：
1. 檢查 IRQ 編號是否在有效範圍內
2. 檢查該 IRQ 是否有已註冊的處理常式
3. 如果有，調用處理常式

## 使用 ISR 框架

### user.c - 使用 ISR 範例

```c
#include "os.h"
#include "mutex.h"
#include "isr.h"

extern volatile int tasks_ready;
extern int taskTop;

mutex_t m;
int shared_counter = 0;

// 用於測試 ISR 被調用的次數
static volatile int isr_call_count = 0;

// 自定義 ISR 處理函式
void my_timer_isr(void) {
    isr_call_count++;  // 簡單地增加計數
}
```

這裡定義了一個簡單的 ISR 處理函式，每次被調用時增加計數。

### Task4 註冊 ISR

```c
void user_task4(void) {
    lib_printf("Task4 [hart %d]: Created!\n", r_mhartid());
    
    // 註冊 IRQ 5 的 ISR
    lib_printf("Task4: registering ISR for IRQ 5...\n");
    isr_register(5, my_timer_isr);
    lib_printf("Task4: ISR registered, call_count=%d\n", isr_call_count);
    
    int last_count = 0;
    while (1) {
        // 檢查 ISR 是否被調用
        if (isr_call_count != last_count) {
            lib_printf("Task4 [hart %d]: ISR called! count=%d\n", r_mhartid(), isr_call_count);
            last_count = isr_call_count;
        }
        
        // 正常的任務邏輯
        mutex_lock(&m);
        lib_printf("Task4 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task4 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        
        task_yield();
        lib_delay(200);
    }
}
```

Task4 展示了如何在任務中註冊和使用 ISR：
1. 初始化時註冊 ISR 到 IRQ 5
2. 在任務迴圈中檢查 ISR 是否被調用
3. 如果 ISR 被調用，輸出訊息

### 初始化函式

```c
void user_init() {
    mutex_init(&m);
    task_create(&user_task0);
    task_create(&user_task1);
    task_create(&user_task2);
    task_create(&user_task3);
    task_create(&user_task4);
    lib_printf("user_init: created %d tasks\n", taskTop);
    tasks_ready = 1;
}
```

創建五個任務，其中 Task4 會註冊 ISR。

## ISR 與系統整合

### 定時器中斷處理

在真正的系統中，ISR 需要與硬體中斷整合。定時器中斷發生時：

```c
void timer_handler() {
    // 禁用定時器中斷
    w_mie(~((~r_mie()) | (1 << 7)));
    
    // 分發自定義 ISR（如果已註冊）
    isr_dispatch(5);  // 假設使用 IRQ 5
    
    // 重新設置定時器
    int id = r_mhartid();
    *(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
    
    // 切換回 OS
    task_os();
    
    // 重新啟用定時器中斷
    w_mie(r_mie() | MIE_MTIE);
}
```

這是一個整合範例，在定時器中斷處理常式中調用 isr_dispatch。

### 中斷上下文

處理 ISR 時需要注意：
- ISR 在中斷上下文執行，不是任務上下文
- ISR 應該盡快完成，不應該阻塞
- ISR 不能使用任務的堆疊（應該使用專門的中斷堆疊）

## ISR 框架的優勢

### 動態 vs 靜態

**靜態 ISR**（本專案前幾階段）：
- 處理常式在編譯時就確定
- 無法在執行時變更
- 適用於簡單系統

**動態 ISR**（本階段）：
- 處理常式可以在執行時註冊
- 允許載入卸載驅動程式
- 更靈活但實現更複雜

### 驅動程式模型

現代作業系統使用 ISR 框架構建驅動程式：

1. **驅動程式初始化**：註冊 ISR 到特定的 IRQ
2. **中斷發生**：硬體觸發中斷
3. **分發**：系統找到對應的 ISR 並調用
4. **處理**：ISR 執行必要的操作
5. **返回**：控制權返回到被中斷的任務

## 編譯與執行

### 編譯指令

```sh
make clean
make
```

注意需要編譯 isr.c：
```
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv64ima_zicsr -mabi=lp64 -T os.ld -o os.elf start.s sys.s lib.c timer.c task.c mutex.c os.c user.c isr.c
```

### 執行指令

```sh
make qemu
```

### 預期輸出

```
OS start
Task0 [hart 0]: Created!
Task0 [hart 0]: counter before = 0
Task0 [hart 0]: counter after  = 1
Task1 [hart 0]: Created!
Task1 [hart 0]: counter before = 1
Task1 [hart 0]: counter after  = 2
Task4: registering ISR for IRQ 5...
Task4: ISR registered, call_count=0
Task4 [hart 0]: ISR called! count=1
Task4 [hart 0]: counter before = 2
Task4 [hart 0]: counter after  = 3
Task4 [hart 0]: ISR called! count=2
Task4 [hart 0]: counter before = 3
Task4 [hart 0]: counter after  = 4
...
```

注意 Task4 成功註冊 ISR，並且定時器中斷會觸發 ISR 調用。

## 重要概念まとめ

### 1. 中斷向量表

ISR 框架類似於中斷向量表：
- 每個 IRQ 編號對應一個處理常式
- 中斷發生時，系統根據 IRQ 找到處理常式
- 這簡化了中斷處理的複雜性

### 2. 中斷優先順序

在複雜系統中，不同的中断有不同的優先順序：
- 硬體中斷控制器的配置
- 軟體優先順序的實現
- 嵌套中斷的處理

本專案簡化了這些概念，專注於核心框架。

### 3. 驅動程式架構

ISR 框架是驅動程式的基礎：
- 每個硬體裝置都需要 ISR
- 驅動程式負責註冊和處理 ISR
- 作業系統提供統一的框架

### 4. 延遲工作中斷處理

在真實的 ISR 中，通常有兩種處理方式：

**頂半部 (Top Half)**：
- 在 ISR 上下文中立即執行
- 必須盡快完成
- 僅做基本處理

**底半部 (Bottom Half)**：
- 推遲到安全時機執行
- 處理較長時間的操作
- 在任務上下文執行

本專案將兩者合併，未來可以擴展為更複雜的架構。

### 5. 進一步擴展

本階段的 ISR 框架可以進一步擴展：

- **多重 ISR**：一個 IRQ 可以有多個處理常式
- **ISR 卸載**：動態移除已註冊的 ISR
- **優先順序**：為 ISR 分配優先順序
- **共享 IRQ**：多個裝置共用一個 IRQ

## 專案總結

經過九個階段的學習，我們實現了一個完整的 mini-riscv-os：

| 階段 | 主題 | 關鍵概念 |
|------|------|----------|
| 01 | Hello OS | 啟動、UART、堆疊 |
| 02 | Context Switch | 上下文保存、切換 |
| 03 | Multi-Tasking | 合作式多任務、排程 |
| 04 | Timer Interrupt | 定時器、CSR、中斷 |
| 05 | Preemptive | 搶先式多任務、時間片 |
| 06 | Mutex | 同步、臨界區 |
| 07 | Multicore 32bit | 多核心、SMP |
| 08 | Multicore 64bit | 64 位元、LP64 ABI |
| 09 | Interrupt ISR | ISR 框架、驅動程式 |

這個 mini-riscv-os 涵蓋了作業系統的核心概念：
- 程序/執行緒管理
- 排程
- 同步
- 中斷處理
- 多核心支援

## 下一步

本專案到此結束。你可以：
- 擴展 ISR 框架
- 添加檔案系統
- 實現虛擬記憶體
- 新增網路驅動程式
- 探索更多 RISC-V 特性を

## 相關資源

- RISC-V 中斷架構: https://riscv.org/specifications/
- ISR 設計模式: https://en.wikipedia.org/wiki/Interrupt_handler
- 驅動程式開發: https://en.wikipedia.org/wiki/Device_driver
- 作業系統架構: https://en.wikipedia.org/wiki/Operating_system
