# 07-Multicore-32bit

## 概述

這是 mini-riscv-os 的第七個階段，實現 32 位元 RISC-V 的多核心支援。到目前為止，所有任務都在單個 CPU 核心（hart 0）上執行。在現代計算機中，多核心處理器是標準配置，因此作業系統必須能夠有效地利用多個核心。本階段將展示如何在多個 hart 上同時執行任務，實現真正的並行處理。

多核心作業系統與單核心有本質區別：
- 每個核心有獨立的定時器中斷
- 任務可以同時在多個核心上執行
- 共享資源的訪問需要更嚴格的同步機制
- 需要處理核心之間的初始化協調

## RISC-V 中的核心概念

### Hart vs Core

在 RISC-V 術語中：
- **Hart** (Hardware Thread): 硬體執行緒，是 RISC-V 中的基本執行單元
- **Core** (Core): 包含一個或多個 hart 的處理器實體

在 QEMU virt 機器中，我們可以模擬多個 hart，它們相當於多個邏輯 CPU。

### mhartid - 識別 hart ID

每個 hart 有一個唯一的 ID，可以透過 `mhartid` CSR 讀取：

```c
static inline reg_t r_mhartid() {
    reg_t x;
    asm volatile("csrr %0, mhartid" : "=r" (x));
    return x;
}
```

在 QEMU 中，我們可以使用 `-smp 4` 選項模擬 4 個 hart。

## 多核心初始化流程

### start.s 的修改

在多核心環境中，每個 hart 都會執行啟動碼：

```assembly
_start:
    # 設定每個 hart 的堆疊
    csrr t0, mhartid
    slli t0, t0, 10
    la   sp, stacks + STACK_SIZE
    add  sp, sp, t0
    
    # 所有 hart 都執行這裡
    csrr a0, mhartid
    bnez a0, park
    
    j    os_main

park:
    wfi
    j park
```

與單核心版本不同：
- 每個 hart 有自己的堆疊（透過 mhartid 計算偏移）
- 每個 hart 都會檢查自己的 ID
- 非 0 的 hart 進入 park 狀態待機

### 初始化協調

多核心系統啟動時的問題：
1. 哪個 hart 負責初始化任務？
2. 其他 hart 如何知道任務已初始化完成？
3. 每個 hart 應該執行哪個任務？

解決方案：使用同步變數

```c
volatile int tasks_ready = 0;   // 任務是否已初始化
volatile int harts_ready = 0;   // 已準備好的 hart 數量
```

### os.c - 多核心初始化

```c
volatile int tasks_ready = 0;
volatile int harts_ready = 0;

void os_kernel() {
    task_os();
}

void os_start() {
    int id = r_mhartid();  // 獲取目前 hart 的 ID
    
    lib_printf("Hart %d: in os_start\n", id);
    
    // Hart 0 負責初始化任務
    if (id == 0) {
        lib_printf("Hart %d: OS start, initializing tasks\n", id);
        user_init();                  // 初始化任務
        __sync_synchronize();         // 記憶體屏障
        tasks_ready = 1;              // 標記任務已初始化
        lib_printf("Hart %d: tasks_ready = 1\n", id);
    }
    
    // 其他 hart 等待 Hart 0 初始化完成
    lib_printf("Hart %d: waiting for tasks_ready\n", id);
    while (!tasks_ready) {}           // 輪詢等待
    __sync_synchronize();
    
    // 每個 hart 初始化自己的排程器
    lib_printf("Hart %d: init scheduler\n", id);
    init_scheduler(id);              // 初始化此 hart 的排程器
    timer_init();                     // 初始化定時器
    __sync_synchronize();
    harts_ready++;
    
    lib_printf("Hart %d: done, harts_ready=%d\n", id, harts_ready);
}

int os_main(void) {
    os_start();
    
    while (1) {
        int my_task = scheduler_next();  // 每個 hart 調度自己的任務
        task_go(my_task);
    }
    return 0;
}
```

### __sync_synchronize() - 記憶體屏障

`__sync_synchronize()` 是 GCC 的內建函式，用於建立記憶體屏障：
- 確保所有讀寫操作在此之前完成
- 防止編譯器和 CPU 重新排序記憶體操作
- 這對於多核心同步至關重要

## 多核心排程

### 每個 hart 獨立排程

在多核心系統中，每個 hart 都執行自己的排程器：

```c
int scheduler_next() {
    // 每個 hart 維護自己的目前任務指標
    static int current_task_per_hart[NCPU] = {0};
    
    int hart_id = r_mhartid();
    int task = current_task_per_hart[hart_id];
    
    // 簡單的 Round-Robin
    task = (task + 1) % taskTop;
    current_task_per_hart[hart_id] = task;
    
    return task;
}
```

每個 hart 追蹤自己的目前任務，實現獨立的排程。

### 任務分配策略

可以採用多種任務分配策略：

1. **靜態分配**: 每個 hart 固定執行某些任務
2. **負載均衡**: 將任務均勻分配到各 hart
3. **親和性**: 某些任務偏好特定 hart

本專案使用簡單的 Round-Robin，每個 hart 輪流執行任務。

## 多核心定時器

### 每個 hart 有獨立的定時器

在 CLINT 中，每個 hart 有自己的 MTIMECMP 暫存器：

```c
void timer_init() {
    int id = r_mhartid();  // 使用此 hart 的 ID
    *(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
    // ... 設置中斷
}
```

每個 hart 的定時器獨立運作，產生獨立的定時器中斷。

## 跨核心同步

### 多核心互斥鎖

在第六階段實現的互斥鎖同樣適用於多核心環境，因為使用了原子操作：

```c
void mutex_lock(mutex_t *m) {
    while (1) {
        while (m->locked) {}                    // 忙等待
        if (__sync_bool_compare_and_swap(&m->locked, 0, 1)) {
            return;                             // 原子操作，成功獲取
        }
    }
}
```

`__sync_bool_compare_and_swap` 是原子操作，即使在多核心環境中也能正確工作。

### 共享計數器的訪問

```c
mutex_t m;
int shared_counter = 0;

void user_task0(void) {
    lib_printf("Task0 [hart %d]: Created!\n", r_mhartid());
    while (1) {
        mutex_lock(&m);
        lib_printf("Task0 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task0 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        task_yield();
        lib_delay(200);
    }
}
```

注意：
- 每次訪問 shared_counter 都需要獲取互斥鎖
- 這確保即使多個 hart 同時執行，也不會有競爭條件
- `r_mhartid()` 用於顯示任務在哪個 hart 上執行

## user.c - 多核心範例

```c
#include "os.h"
#include "mutex.h"

extern volatile int tasks_ready;
extern int taskTop;

mutex_t m;
int shared_counter = 0;

// 五個任務
void user_task0(void) {
    lib_printf("Task0 [hart %d]: Created!\n", r_mhartid());
    while (1) {
        mutex_lock(&m);
        lib_printf("Task0 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task0 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        task_yield();
        lib_delay(200);
    }
}

// ... user_task1 到 user_task4 類似

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

## 編譯與執行

### Makefile 配置

```makefile
CC = riscv64-unknown-elf-gcc
CFLAGS = -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima_zicsr -mabi=ilp32

QEMU = qemu-system-riscv32
QFLAGS = -nographic -smp 4 -machine virt -bios none
```

注意 `-smp 4` 選項，指示 QEMU 模擬 4 個 hart。

### 執行指令

```sh
make clean
make
make qemu
```

### 預期輸出

```
OS start
Hart 0: OS start, initializing tasks
Hart 0: tasks_ready = 1
Hart 0: init scheduler
Hart 0: done, harts_ready=1
Hart 1: in os_start
Hart 1: waiting for tasks_ready
Hart 1: init scheduler
Hart 1: done, harts_ready=2
Hart 2: in os_start
Hart 2: waiting for tasks_ready
Hart 2: init scheduler
Hart 2: done, harts_ready=3
Hart 3: in os_start
Hart 3: waiting for tasks_ready
Hart 3: init scheduler
Hart 3: done, harts_ready=4
Task0 [hart 0]: Created!
Task0 [hart 0]: counter before = 0
Task0 [hart 0]: counter after  = 1
Task1 [hart 0]: Created!
...
```

注意觀察：
- 所有 4 個 hart 都啟動並初始化
- Task0 和 Task1 在 hart 0 上執行
- 多核心同時執行任務

## 多核心的重要概念

### 1. SMP - 對稱多處理

SMP (Symmetric Multiprocessing) 是多核心作業系統的基本模型：
- 所有核心平等存取記憶體和 I/O
- 作業系統可以在任何核心上排程任務
- 需要同步機制保護共享資源

本專案實現的是 SMP 架構。

### 2. 緩慢一致性問題

在多核心系統中，每個核心有自己的快取：
- 快取一致性協議（如 MESI）確保資料一致
- 但仍可能出現可見性問題
- 記憶體屏障解決這個問題

### 3. 快取行競爭

當多個核心訪問同一個快取行（cache line）時：
- 即使訪問不同變數，也可能產生競爭
- 稱為「False Sharing」
- 可以透過對齊和填充避免

### 4. 負載均衡

在真正的多核心系統中：
- 某些核心可能忙碌，某些空閒
- 作業系統需要動態調整任務分配
- 這稱為負載均衡（Load Balancing）

### 5. 通訊與同步

多核心間的通訊方式：
- **共享記憶體**: 最常見，需要同步
- **訊息傳遞**: MPI 等框架
- **軟體中斷**: 透過 CLINT 發送訊號

## 與單核心的比較

| 特性 | 單核心 | 多核心 |
|------|--------|--------|
| 並發性 | 假並發（時間片） | 真並發 |
| 同步需求 | 較低 | 高 |
| 初始化 | 簡單 | 需要協調 |
| 排程 | 簡單 | 複雜 |
| 性能 | 受限於單核心 | 可線性擴展 |

## 下一步

下一課 [[08-Multicore-64bit]] 將把多核心支援擴展到 64 位元 RISC-V (rv64ima)，這是現代高效能運算的標準架構。

## 相關資源

- RISC-V Multicore: https://riscv.org/technical/
- SMP 作業系統: https://en.wikipedia.org/wiki/Symmetric_multiprocessing
- 快取一致性: https://en.wikipedia.org/wiki/Cache_coherence
- 負載均衡: https://en.wikipedia.org/wiki/Load_balancing_(computing)
