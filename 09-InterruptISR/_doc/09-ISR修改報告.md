# 09-InterruptISR 修改報告

## 概述

在 64-bit 多核心 OS (Chapter 07b) 基礎上，新增 ISR (Interrupt Service Routine) 中斷向量表功能，讓系統可以支援多個中斷來源，並允許使用者任務註冊自訂的中斷處理常式。

---

## 新增功能

### 1. ISR 中斷向量表

- 支援最多 16 個 IRQ (MAX_ISR = 16)
- 靜態表格結構，根據 IRQ 號碼註冊處理常式
- 提供 `isr_register()` 讓任務註冊自己的 ISR
- 提供 `isr_dispatch()` 根據 IRQ 號碼分派到對應的 ISR

### 2. Timer ISR 整合

- Timer 現在透過 ISR 框架處理
- `timer_handler_isr()` 會遞迴呼叫下一個 timer 中斷
- 與原本的 `timer_handler()` 並存，相容原有功能

### 3. 測試任務

- Task4 示範如何註冊自訂 ISR
- 註冊 IRQ 5 的測試 ISR
- 每當 ISR 被呼叫時輸出計數

---

## 程式碼修改

### 1. 新增 isr.h

```c
#ifndef __ISR_H__
#define __ISR_H__

#include "riscv.h"

#define MAX_ISR 16

typedef void (*isr_handler_t)(void);

typedef struct {
    int irq;
    isr_handler_t handler;
} isr_entry_t;

void isr_init();
int  isr_register(int irq, isr_handler_t handler);
void isr_dispatch(int irq);

#endif
```

**說明**：
- 定義 ISR 表格大小為 16 個項目
- 函式指標類型用於 ISR 處理常式
- 提供 init、register、dispatch 三個主要 API

---

### 2. 新增 isr.c

```c
#include "isr.h"

static isr_entry_t isr_table[MAX_ISR];
static int isr_count = 0;

void isr_init() {
    for (int i = 0; i < MAX_ISR; i++) {
        isr_table[i].irq = -1;
        isr_table[i].handler = 0;
    }
    isr_count = 0;
}

int isr_register(int irq, isr_handler_t handler) {
    if (irq < 0 || irq >= MAX_ISR) {
        return -1;
    }
    
    isr_table[irq].irq = irq;
    isr_table[irq].handler = handler;
    return 0;
}

void isr_dispatch(int irq) {
    if (irq >= 0 && irq < MAX_ISR) {
        if (isr_table[irq].handler != 0) {
            isr_table[irq].handler();
        }
    }
}
```

**說明**：
- `isr_init()`: 初始化表格，將所有項目清除
- `isr_register()`: 根據 IRQ 號碼註冊處理常式
- `isr_dispatch()`: 根據 IRQ 號碼找到對應的 ISR 並執行

---

### 3. 修改 timer.h

```c
extern void timer_handler();
extern void timer_handler_isr();  // 新增
extern void timer_init();

#define TIMER_IRQ 7
```

**說明**：
- 新增 `timer_handler_isr()` 函式宣告
- 定義 Timer IRQ 號碼為 7

---

### 4. 修改 timer.c

```c
void timer_init()
{
  ...
  isr_register(TIMER_IRQ, timer_handler_isr);  // 新增
}

void timer_handler_isr() {
  int id = r_mhartid();
  timer_count_per_hart[id]++;
  timer_count++;
  
  uint64_t now = get_mtime();
  uint64_t interval = timer_scratch[id][4];
  set_mtimecmp(now + interval);
  
  task_os();
}
```

**說明**：
- 在 `timer_init()` 中註冊 timer ISR
- `timer_handler_isr()` 處理 timer 中斷並安排下一次中斷

---

### 5. 修改 os.h

```c
#include "isr.h"  // 新增
```

---

### 6. 修改 os.c

```c
void os_start() {
    if (id == 0) {
        lib_printf("Hart %d: OS start, initializing ISR\n", id);
        isr_init();  // 新增
        lib_printf("Hart %d: OS start, initializing tasks\n", id);
        ...
    }
}
```

**說明**：
- 在 OS 啟動時初始化 ISR 表格

---

### 7. 修改 user.c (測試)

```c
static volatile int isr_call_count = 0;

void my_timer_isr(void) {
    isr_call_count++;
}

void user_task4(void)
{
    lib_printf("Task4: registering ISR for IRQ 5...\n");
    isr_register(5, my_timer_isr);
    lib_printf("Task4: ISR registered, call_count=%d\n", isr_call_count);
    
    int last_count = 0;
    while (1) {
        if (isr_call_count != last_count) {
            lib_printf("Task4 [hart %d]: ISR called! count=%d\n", r_mhartid(), isr_call_count);
            last_count = isr_call_count;
        }
        ...
    }
}
```

**說明**：
- Task4 註冊 IRQ 5 的自訂 ISR
- 每當 ISR 被呼叫時輸出計數，驗證 ISR 框架運作正常

---

### 8. 修改 Makefile

```makefile
os.elf: start.s sys.s lib.c timer.c task.c mutex.c os.c user.c isr.c
    $(CC) $(CFLAGS) -T os.ld -o os.elf $^
```

**說明**：
- 加入 `isr.c` 到編譯清單

---

## 測試結果

```
Hart 0: in os_start
Hart 0: OS start, initializing ISR
Hart 0: OS start, initializing tasks
user_init: created 5 tasks
Hart 0: tasks_ready = 1
Hart 0: init scheduler
Hart 0: done, harts_ready=1
Task0 [hart 0]: Created!
Task1 [hart 0]: Created!
Task2 [hart 0]: Created!
Task3 [hart 0]: Created!
Task4 [hart 0]: Created!
Task4: registering ISR for IRQ 5...
Task4: ISR registered, call_count=0
Task0 [hart 0]: counter before = 0
Task0 [hart 0]: counter after  = 1
...
Task4 [hart 0]: ISR called! count=0
Task4 [hart 0]: ISR called! count=1
Task4 [hart 0]: ISR called! count=2
...
```

---

## 總結

這次擴充实现了：

1. **ISR 框架** - 基本的 ISR 表格管理
2. **Timer 整合** - Timer 現在透過 ISR 框架處理
3. **測試範例** - Task4 展示如何註冊和使用自訂 ISR

這個框架可以進一步擴充支援：
- GPIO 中斷
- UART 接收中斷
- 外部裝置中斷
- 中斷優先級
- 中斷巢狀