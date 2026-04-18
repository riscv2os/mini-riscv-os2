# 06-Mutex

## 概述

這是 mini-riscv-os 的第六個階段，引入互斥鎖 (Mutex，Mutual Exclusion) 的概念來解決搶先式多任務中的共享資源競爭問題。在第五階段實現的搶先式多任務中，多個任務並發執行，雖然提高了系統的響應性和公平性，但也引入了一個重要的問題：當多個任務同時訪問共享資源時，可能會產生競爭條件 (Race Condition)，導致資料不一致或系統錯誤。

互斥鎖是最基本的同步原語，它確保一次只有一個任務能夠進入臨界區 (Critical Section)，從而保護共享資源的完整性。

## 競爭條件的問題

### 什麼是臨界區？

臨界區是指訪問共享資源（如全域變數、檔案、硬體等）的程式碼區域。在臨界區內，原則上只應有一個任務執行，以避免資料競爭。

例如，以下程式碼存在問題：

```c
int shared_counter = 0;

void user_task0(void) {
    while (1) {
        // 讀取 shared_counter
        int temp = shared_counter;
        
        // 延遲一段時間（讓其他任務有機會執行）
        lib_delay(10);
        
        // 增加計數器
        shared_counter = temp + 1;
        
        lib_printf("Task0: counter = %d\n", shared_counter);
    }
}

void user_task1(void) {
    while (1) {
        int temp = shared_counter;
        lib_delay(10);
        shared_counter = temp + 1;
        lib_printf("Task1: counter = %d\n", shared_counter);
    }
}
```

### 競爭條件的具體分析

假設 `shared_counter` 初始值為 0，兩個任務同時啟動：

1. Task0 讀取 `shared_counter` (temp0 = 0)
2. Task1 也讀取 `shared_counter` (temp1 = 0) - 注意！這裡發生了競爭
3. Task0 計算並寫入 `shared_counter = 1`
4. Task1 也計算並寫入 `shared_counter = 1`
5. 結果：兩個任務都執行了 counter++，但最終值是 1 而不是 2

這就是經典的「讀取-修改-寫入」競爭條件。即使在搶先式系統中，由於任務可能被中斷，這種情況隨時都可能發生。

## 互斥鎖的原理

### 什麼是互斥鎖？

互斥鎖是一種同步機制，確保在任意時刻只有一個執行緒能夠持有特定的鎖。當一個任務想要進入臨界區時，它必須：
1. 獲取互斥鎖
2. 執行臨界區程式碼
3. 釋放互斥鎖

如果另一個任務已經持有互斥鎖，則新任務必須等待，直到鎖被釋放。

### 互斥鎖的狀態

互斥鎖有兩種狀態：
- **Unlocked (未鎖定)**: 沒有任務持有，可以自由獲取
- **Locked (已鎖定)**: 已有任務持有，其他任務需要等待

### 實現方式

互斥鎖的實現有多種方式：

**1. 硬體指令實現**
- 使用特殊的原子指令（如 x86 的 `xchg`，RISC-V 的 `lr/sc`）
- 這是最可靠的方式

**2. 軟體實現**
- 使用軟體迴圈等待（spinlock）
- 適用於單核心或簡單系統

**3. 作業系統支援**
- 作業系統提供更高級的同步原語
- 可以實現阻塞等待

本專案使用 GCC 的內建原子操作 `__sync_bool_compare_and_swap`，這是軟體實現但足夠可靠。

## mutex.h 和 mutex.c 實現

### mutex.h - 互斥鎖類型定義

```c
#ifndef __MUTEX_H__
#define __MUTEX_H__

#include "riscv.h"

typedef struct {
    int locked;   // 鎖的狀態：0 = 未鎖定，1 = 已鎖定
    int owner;   // 持有鎖的任務 ID
} mutex_t;

// 初始化互斥鎖
void mutex_init(mutex_t *m);
// 獲取互斥鎖
void mutex_lock(mutex_t *m);
// 釋放互斥鎖
void mutex_unlock(mutex_t *m);

#endif
```

### mutex.c - 互斥鎖實現

```c
#include "mutex.h"

void mutex_init(mutex_t *m) {
    m->locked = 0;
    m->owner = -1;
}

void mutex_lock(mutex_t *m) {
    while (1) {
        // 等待鎖變為未鎖定
        while (m->locked) {
            // 忙等待（spinlock）
        }
        
        // 嘗試原子性地獲取鎖
        if (__sync_bool_compare_and_swap(&m->locked, 0, 1)) {
            // 成功獲取鎖
            return;
        }
        // 如果失敗，繼續迴圈嘗試
    }
}

void mutex_unlock(mutex_t *m) {
    m->locked = 0;
}
```

### 實現原理說明

**1. 初始狀態**
```c
void mutex_init(mutex_t *m) {
    m->locked = 0;  // 鎖為未鎖定狀態
}
```

**2. 獲取鎖的過程**
```c
void mutex_lock(mutex_t *m) {
    while (1) {
        // 第一步：忙等待
        while (m->locked) {}
        
        // 第二步：原子比較並交換
        if (__sync_bool_compare_and_swap(&m->locked, 0, 1)) {
            return;  // 成功獲取鎖
        }
        // 否則重試
    }
}
```

這裡使用了 `__sync_bool_compare_and_swap` 函式，它是 GCC 的內建函式，提供原子的比較和交換操作：
- 語法：`bool __sync_bool_compare_and_swap(type *ptr, type oldval, type newval)`
- 功能：如果 `*ptr == oldval`，則原子性地將 `*ptr` 設為 `newval` 並返回 true
- 否則返回 false，且不修改 `*ptr`

**為什麼需要這個複雜的邏輯？**

考慮以下情況：
1. 任務 A 檢查 `m->locked`，發現為 0
2. 在任務 A 執行 `CAS` 之前，任务 B 也检查了 `m->locked`，也发现为 0
3. 如果没有原子操作，两个任务都会认为可以获取锁
4. 使用原子操作后，只有一个任务能成功将 locked 设为 1

**3. 釋放鎖**
```c
void mutex_unlock(mutex_t *m) {
    m->locked = 0;
}
```

釋放鎖很簡單，只需要將 `locked` 設為 0 即可。此時其他等待中的任務可以獲取鎖。

## 使用互斥鎖保護共享資源

### user.c - 使用範例

```c
#include "os.h"
#include "mutex.h"

mutex_t m;
int shared_counter = 0;

void user_task0(void) {
    lib_puts("Task0: Created!\n");
    while (1) {
        mutex_lock(&m);                    // 獲取鎖
        lib_printf("Task0: counter before = %d\n", shared_counter);
        shared_counter++;                  // 訪問共享資源
        lib_printf("Task0: counter after  = %d\n", shared_counter);
        mutex_unlock(&m);                  // 釋放鎖
        lib_delay(1000);
    }
}

void user_task1(void) {
    lib_puts("Task1: Created!\n");
    while (1) {
        mutex_lock(&m);
        lib_printf("Task1: counter before = %d\n", shared_counter);
        shared_counter++;
        lib_printf("Task1: counter after  = %d\n", shared_counter);
        mutex_unlock(&m);
        lib_delay(1000);
    }
}

void user_init() {
    mutex_init(&m);          // 初始化互斥鎖
    task_create(&user_task0);
    task_create(&user_task1);
}
```

### 臨界區的保護

使用互斥鎖後，任務訪問共享資源的順序變成：

1. **mutex_lock(&m)**: 嘗試獲取互斥鎖
   - 如果鎖可用，立即獲取並繼續
   - 如果鎖被占用，等待直到鎖可用

2. **臨界區**: 執行訪問共享資源的程式碼
   - 這個時候，只有當前任務在執行臨界區
   - 其他任務無法進入臨界區

3. **mutex_unlock(&m)**: 釋放互斥鎖
   - 允許其他任務進入臨界區

### 執行流程分析

假設 shared_counter = 0，Task0 和 Task1 同時運行：

1. Task0 調用 `mutex_lock(&m)`:
   - m->locked = 0，CAS 成功
   - m->locked 變為 1
   - Task0 進入臨界區

2. Task0 在臨界區中：
   - 輸出 "Task0: counter before = 0"
   - shared_counter++ (變為 1)
   - 輸出 "Task0: counter after = 1"

3. Task0 調用 `mutex_unlock(&m)`:
   - m->locked 變為 0

4. Task1 獲取互斥鎖：
   - 此時 m->locked = 0，Task1 成功獲取
   - m->locked 變為 1

5. Task1 在臨界區中：
   - 輸出 "Task1: counter before = 1"
   - shared_counter++ (變為 2)
   - 輸出 "Task1: counter after = 2"

6. Task1 釋放互斥鎖
7. 如此迴圈

結果：每次 counter 都正確遞增，不會丢失任何一次更新。

## 編譯與執行

### 編譯指令

```sh
make clean
make
```

注意這次需要編譯 `mutex.c` 檔案：
```
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima_zicsr -mabi=ilp32 -T os.ld -o os.elf start.s sys.s lib.c timer.c task.c mutex.c os.c user.c
```

### 執行指令

```sh
make qemu
```

### 預期輸出

```
OS start
Task0: Created!
Task0: counter before = 0
Task0: counter after  = 1
Task1: Created!
Task1: counter before = 1
Task1: counter after  = 2
Task0: counter before = 2
Task0: counter after  = 3
Task1: counter before = 3
Task1: counter after  = 4
...
```

注意觀察：
- counter 每次遞增 1，沒有丢失
- Task0 和 Task1 交替執行
- 每個任務都能正確讀取和修改 shared_counter

## 重要概念まとめ

### 1. 競爭條件 vs 臨界區

**競爭條件 (Race Condition)**:
- 多個任務並發訪問共享資源
- 最終結果取決於任務執行的時序
- 難以預測和調試

**臨界區 (Critical Section)**:
- 訪問共享資源的程式碼區域
- 需要保護，確保一次只有一個任務能進入

### 2. 互斥鎖的特性

互斥鎖必須滿足以下條件：

**互斥 (Mutual Exclusion)**:
- 一次只能有一個任務持有鎖

**Progress (進展)**:
- 如果沒有人持有鎖，且有任務想要獲取，應該允許獲取

**Bounded Waiting (有限等待)**:
- 任務等待鎖的時間應該是有限的
- 不能出現飢餓 (Starvation) 問題

### 3. 忙等待 vs 阻塞等待

本專案使用**忙等待 (Busy Waiting / Spinlock)**：
- 優點：實現簡單，不需要作業系統支援
- 缺點：浪費 CPU 週期

真實作業系統使用**阻塞等待**：
- 任務進入阻塞狀態，不消耗 CPU
- 當鎖可用時，作業系統喚醒等待的任務

### 4. 死鎖的風險

使用互斥鎖時需要注意死鎖 (Deadlock) 問題：

**死鎖的必要條件**：
1. 互斥：資源一次只能被一個任務使用
2. 持有並等待：任務持有資源並等待其他資源
3. 不搶先：資源不能被強制搶奪
4. 循環等待：形成任務等待環

**避免死鎖的方法**：
- 總是以相同順序獲取多個鎖
- 設定超時機制
- 使用deadlock detection

### 5. 臨界區的最佳實踐

- **盡量縮短臨界區**: 臨界區越短，其他任務等待時間越短
- **不要在臨界區中呼叫阻塞函式**: 否則會導致其他任務長期等待
- **避免嵌套鎖**: 減少死鎖風險

## 下一步

下一課 [[07-Multicore-32bit]] 將把系統擴展到多核心 (Multicore)，讓多個 CPU 核心同時執行任務。這是現代作業系統的重要特徵，也帶來新的同步挑戰。

## 相關資源

- 互斥鎖維基百科: https://en.wikipedia.org/wiki/Mutex
- 臨界區: https://en.wikipedia.org/wiki/Critical_section
- 競爭條件: https://en.wikipedia.org/wiki/Race_condition
- 死鎖: https://en.wikipedia.org/wiki/Deadlock
- 原子操作: https://en.wikipedia.org/wiki/Linearizable
