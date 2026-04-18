# 08-Multicore-64bit

## 概述

這是 mini-riscv-os 的第八個階段，將多核心支援擴展到 64 位元 RISC-V 架構 (rv64ima)。64 位元 RISC-V 是現代高效能運算的標準，它提供了更大的位址空間、更高的運算效能，以及更豐富的指令集。這個階段展示如何將 32 位元系統遷移到 64 位元，並保持多核心和多任務的能力。

64 位元與 32 位元的主要差異在於：
- 暫存器寬度從 32 位元增加到 64 位元
- 記憶體位址空間從 4GB 擴展到幾乎無限
- ABI (Application Binary Interface) 改變為 LP64
- 工具鏈和模擬器都需要使用 64 位元版本

## RISC-V 64 位元架構

### rv64ima vs rv32ima

RISC-V 架構的命名規則：
- **位元寬度**: rv32 (32 位元) vs rv64 (64 位元)
- **ISA 標準**: i (基本整數), m (乘除), a (原子), f (浮點), d (雙精度), g (通用)
- **擴充**: zicsr (控制狀態暫存器), zifencei (指令屏障)

本專案使用：
- **rv64ima**: 64 位元，整數+乘除+原子
- **zicsr**: 允許使用 CSR 指令

### LP64 ABI

ABI (Application Binary Interface) 定義了函式呼叫和資料表示的規則。LP64 是 64 位元 Unix/Linux 系統的標準 ABI：

| 類型 | 大小 (位元組) |
|------|---------------|
| long | 8 |
| long long | 8 |
| pointer | 8 |
| int | 4 |
| short | 2 |
| char | 1 |
| float | 4 |
| double | 8 |

這與 ILP32 (32 位元的 ABI) 完全不同：
- ILP32: int=4, long=4, pointer=4
- LP64: int=4, long=8, pointer=8

### reg_t 的變化

在 32 位元系統中：
```c
#define reg_t uint32_t
```

在 64 位元系統中：
```c
#define reg_t uint64_t
```

這意味著所有記憶體操作和暫存器操作都需要使用 64 位元類型。

## 工具鏈的差異

### 編譯器

32 位元系統使用：
```
riscv64-unknown-elf-gcc -march=rv32ima -mabi=ilp32 ...
```

64 位元系統使用：
```
riscv64-unknown-elf-gcc -march=rv64ima -mabi=lp64 ...
```

注意：我們仍然使用 riscv64-unknown-elf-gcc 工具鏈，它是 64 位元編譯器，可以產生 32 位元或 64 位元的程式碼。

### 模擬器

32 位元系統使用：
```
qemu-system-riscv32 ...
```

64 位元系統使用：
```
qemu-system-riscv64 ...
```

### Makefile 配置

```makefile
# 32 位元版本
CFLAGS_32 = -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima_zicsr -mabi=ilp32
QEMU_32 = qemu-system-riscv32

# 64 位元版本
CFLAGS_64 = -nostdlib -fno-builtin -mcmodel=medany -march=rv64ima_zicsr -mabi=lp64
QEMU_64 = qemu-system-riscv64
```

## 程式碼修改

### riscv.h 的修改

```c
// 32 位元版本
#define reg_t uint32_t

// 64 位元版本
#define reg_t uint64_t
```

在 64 位元版本中，所有 `reg_t` 類型的暫存器都變成 64 位元。

### 組合語言的修改

組合語言指令需要使用 64 位元版本：
- `sd` (Store Doubleword): 儲存 64 位元
- `ld` (Load Doubleword): 載入 64 位元
- `addiw`: 32 位元加法立即數
- `slliw`, `srliw`: 32 位元移位

在 64 位元系統中：
- `addi` 仍然是 32 位元加法
- 需要使用 `addiw` 進行符號擴展的 32 位元加法
- 記憶體對齊要求可能更嚴格

### 堆疊配置

64 位元系統的堆疊配置與 32 位元類似，但堆疊指標是 64 位元：

```assembly
# 64 位元版本
la   sp, stacks + STACK_SIZE
add  sp, sp, t0      # t0 已經是 64 位元
```

## sys.s 的修改

組合語言上下文切換需要使用 64 位元指令：

```assembly
# 64 位元版本
.global sys_switch

sys_switch:
    # 保存上下文到 ctx_old (a0)
    sd ra, 0(a0)
    sd sp, 8(a0)
    sd s0, 16(a0)
    sd s1, 24(a0)
    # ... 保存其他 s 暫存器
    
    # 恢復上下文從 ctx_new (a1)
    ld ra, 0(a1)
    ld sp, 8(a1)
    ld s0, 16(a1)
    ld s1, 24(a1)
    # ... 恢復其他 s 暫存器
    
    ret
```

## os.c 和排程器

os.c 的邏輯與 32 位元版本幾乎相同，但增加了對 64 位元的處理：

```c
void os_start() {
    int id = r_mhartid();
    
    lib_printf("Hart %d: in os_start\n", id);
    
    if (id == 0) {
        lib_printf("Hart %d: OS start, initializing tasks\n", id);
        user_init();
        __sync_synchronize();
        tasks_ready = 1;
        lib_printf("Hart %d: tasks_ready = 1\n", id);
    }
    
    lib_printf("Hart %d: waiting for tasks_ready\n", id);
    while (!tasks_ready) {}
    __sync_synchronize();
    
    lib_printf("Hart %d: init scheduler\n", id);
    init_scheduler(id);
    timer_init();
    __sync_synchronize();
    harts_ready++;
    
    lib_printf("Hart %d: done, harts_ready=%d\n", id, harts_ready);
}
```

### 排程器的實現

每個 hart 需要維護自己的排程狀態：

```c
void init_scheduler(int hart_id) {
    // 為每個 hart 初始化排程器狀態
    current_task_per_hart[hart_id] = 0;
}

int scheduler_next() {
    int hart_id = r_mhartid();
    int task = current_task_per_hart[hart_id];
    
    task = (task + 1) % taskTop;
    current_task_per_hart[hart_id] = task;
    
    return task;
}
```

## 記憶體管理

### 位址空間

64 位元 RISC-V 提供了巨大的位址空間：
- 理論上支援 2^64 位元組
- 實際上通常限制在 2^48 或 2^56 位元組
- QEMU virt 機器的 RAM 通常從 0x80000000 開始

### 指標和指標運算

在 64 位元系統中：
```c
void *ptr;        // 指針是 8 位元組
int *array;       // 陣列指標是 8 位元組
uintptr_t addr;   // 無符號整數，用於位址運算
```

指標算術會產生不同的結果：
```c
int arr[10];
int *p = &arr[5];
p++;              // 64 位元：p = &arr[6]，指標增加 8 位元組
                  // 32 位元：p = &arr[6]，指標增加 4 位元組
```

### 大型程式碼模型

使用 `-mcmodel=medany` 代碼模型：
- 允許程式碼在 ±2GB 範圍內跳轉
- 適用於作業系統核心和應用程式
- 另一個選擇是 `-mcmodel=medlow`，僅允許 ±2MB 範圍

## user.c - 64 位元範例

```c
#include "os.h"
#include "mutex.h"

extern volatile int tasks_ready;
extern int taskTop;

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

// ... 其他任務類似
```

注意這與 32 位元版本完全相同，這是 C 語言和 ABI 的優勢：原始碼幾乎不需要修改，只需要重新編譯。

## 編譯與執行

### 編譯指令

```sh
make clean
make
```

64 位元編譯命令：
```
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv64ima_zicsr -mabi=lp64 -T os.ld -o os.elf start.s sys.s lib.c timer.c task.c mutex.c os.c user.c
```

### 執行指令

```sh
make qemu
```

注意這會使用 qemu-system-riscv64。

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

輸出與 32 位元版本類似，但底層是 64 位元架構。

## 重要概念まとめ

### 1. LP64 與 ILP32 的差異

**LP64 (64 位元)**:
- long = 64 位元
- pointer = 64 位元
- 主要用於 Unix/Linux

**ILP32 (32 位元)**:
- long = 32 位元
- pointer = 32 位元
- Windows 和嵌入式系統常用

### 2. 64 位元的優勢

- **更大的位址空間**: 可存取超過 4GB 記憶體
- **更大的運算範圍**: 64 位元整數運算
- **更多的暫存器**: 64 位元模式有更多可用暫存器
- **未來擴展性**: 支援更大的資料集

### 3. 遷移策略

從 32 位元遷移到 64 位元：
1. 更換工具鏈 (riscv64-unknown-elf-gcc)
2. 修改編譯參數 (-march=rv64ima -mabi=lp64)
3. 更換模擬器 (qemu-system-riscv64)
4. 測試和驗證
5. 注意指標和長整數類型的變化

### 4. 相容性考量

在 64 位元系統上執行 32 位元程式：
- 需要模擬器和轉換層
- 可能需要額外的函式庫
- 效能會有損失

本專案選擇乾淨的 64 位元編譯，不涉及相容模式。

### 5. 效能考量

64 位元系統的潛在效能影響：
- 指標變大，記憶體使用增加
- 暫存器寬度增加，運算速度可能提升
- 快取效率可能降低

實際效能取決於應用程式的特性。

## 下一步

下一課 [[09-Interrupt-ISR]] 將實現完整的中斷服務常式 (ISR) 註冊和分發系統，這是構建現代作業系統驅動程式的基礎。

## 相關資源

- RISC-V 64-bit ISA: https://riscv.org/specifications/
- LP64 ABI: https://github.com/riscv/riscv-elf-psabi-doc
- 64 位元程式設計: https://en.wikipedia.org/wiki/64-bit_computing
- QEMU RISC-V: https://www.qemu.org/docs/master/system/riscv.html
