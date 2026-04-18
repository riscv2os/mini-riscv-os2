# 02-Context-Switch

## 概述

這是 mini-riscv-os 的第二個階段，實現手動的上下文切換 (Context Switch) 功能。上下文切換是作業系統實現多任務的基礎，它允許 CPU 在不同任務之間切換執行，每個任務都覺得自己獨佔了整個處理器。

本階段不依賴任何中斷機制，而是透過組合語言直接實現任務之間的切換。這是理解作業系統核心機制的關鍵概念。

## 上下文切換的原理

### 什麼是上下文？

上下文 (Context) 指的是 CPU 在執行某個任務時的完整狀態，包括：
- **程式計數器 (PC)**: 下一條要執行的指令位址，在 RISC-V 中對應 `ra` (return address) 暫存器
- **堆疊指標 (SP)**: 目前堆疊的頂端位置
- **一般用途暫存器**: 所有需要保存的暫存器值
- **浮點暫存器** (如果有 F 擴充): 所有浮點暫存器值

### 為什麼需要保存上下文？

當 CPU 從 OS 切換到使用者任務執行時，我們需要保存 OS 的完整狀態，以便稍後返回繼續執行。反之，當從使用者任務返回 OS 時，也需要保存任務的狀態。

如果沒有保存上下文，切換後的任務將無法恢復到切斷前的狀態，導致程式崩潰。

### Callee-saved vs Caller-saved 暫存器

RISC-V 的呼叫約定將暫存器分為兩類：

**Caller-saved (呼叫者保存) 暫存器**:
- `t0-t6`: 臨時暫存器
- `a0-a7`: 函式引數和返回值

這些暫存器在函式呼叫時可能會被覆蓋，呼叫者不能依賴它們在呼叫後保持不變。

**Callee-saved (被呼叫者保存) 暫存器**:
- `s0-s11`: 保存暫存器
- `ra`: 返回位址
- `sp`: 堆疊指標

這些暫存器在函式執行期間必須保持不變。如果被呼叫的函式需要使用這些暫存器，必須先保存它們的值，結束前再恢復。

### 上下文結構定義

```c
#include <stdint.h>

typedef uint32_t reg_t;

struct context {
    reg_t ra;   // x1 - 返回位址
    reg_t sp;   // x2 - 堆疊指標
    
    // x3-x4: gp, tp (通常不需要保存)
    
    // Callee-saved registers
    reg_t s0;   // x8
    reg_t s1;   // x9
    reg_t s2;   // x18
    reg_t s3;   // x19
    reg_t s4;   // x20
    reg_t s5;   // x21
    reg_t s6;   // x22
    reg_t s7;   // x23
    reg_t s8;   // x24
    reg_t s9;   // x25
    reg_t s10;  // x26
    reg_t s11;  // x27
    
    // 有時也會保存 a0-a7
    reg_t a0;
    reg_t a1;
    reg_t a2;
    reg_t a3;
    reg_t a4;
    reg_t a5;
    reg_t a6;
    reg_t a7;
};
```

在 mini-riscv-os 中，我們主要保存 `ra`, `sp`, 和 `s0-s11`，這是最少需要保存的暫存器集合，稱為 "callee-saved registers"。

## sys.s - 組合語言切換實現

### sys_switch 函式

這是上下文切換的核心函式，用組合語言編寫，因為它需要直接操作暫存器和堆疊：

```assembly
.global sys_switch

# void sys_switch(struct context *ctx_old, struct context *ctx_new)
# a0 = ctx_old (要保存目前上下文的位置)
# a1 = ctx_new (要恢復新上下文的位置)

sys_switch:
    # 保存目前任務 (OS) 的上下文到 ctx_old
    
    # 保存返回位址
    sd ra, 0(a0)
    
    # 保存堆疊指標
    addi t0, sp, 0
    sd t0, 8(a0)
    
    # 保存 callee-saved 暫存器
    sd s0, 16(a0)
    sd s1, 24(a0)
    sd s2, 32(a0)
    sd s3, 40(a0)
    sd s4, 48(a0)
    sd s5, 56(a0)
    sd s6, 64(a0)
    sd s7, 72(a0)
    sd s8, 80(a0)
    sd s9, 88(a0)
    sd s10, 96(a0)
    sd s11, 104(a0)
    
    # 恢復新任務的上下文
    ld ra, 0(a1)
    ld t0, 8(a1)
    addi sp, t0, 0
    
    ld s0, 16(a1)
    ld s1, 24(a1)
    ld s2, 32(a1)
    ld s3, 40(a1)
    ld s4, 48(a1)
    ld s5, 56(a1)
    ld s6, 64(a1)
    ld s7, 72(a1)
    ld s8, 80(a1)
    ld s9, 88(a1)
    ld s10, 96(a1)
    ld s11, 104(a1)
    
    # 切換到新任務 (返回到新任務的 ra 位址)
    ret
```

### 指令說明

- `sd` (Store Doubleword): 儲存 64 位元資料（在本專案 32-bit 模式下是 32 位元）
- `ld` (Load Doubleword): 載入 64 位元資料
- `addi`: 加法立即數
- `ret`: 实际上是 `jr ra`，跳轉到 ra 暫存器儲存的位址

### 為什麼使用 ret 而不是 jump？

關鍵在於 `ra` 暫存器的設置。當我們恢復新任務的上下文後，`ra` 已經被設置為新任務函式的位址。執行 `ret` (即 `jr ra`) 時，CPU 會跳轉到新任務繼續執行，而不是返回到 `sys_switch` 的呼叫點。

這就是上下文切換的精髓：我們保存了舊任務的返回位址，當我們恢復新任務時，新任務的返回位址指向任務本身的入口點，所以執行 `ret` 就會開始執行新任務。

## os.c - 任務管理實現

### 任務堆疊配置

```c
#define STACK_SIZE 1024
uint8_t task0_stack[STACK_SIZE];
struct context ctx_os;
struct context ctx_task;
```

每個任務需要自己的堆疊空間。本階段只有一個任務，所以只配置了一個任務堆疊。

### 使用者任務定義

```c
extern void sys_switch();

void user_task0(void) {
    lib_puts("Task0: Context Switch Success !\n");
    while (1) {} // 停在這裡
}
```

這是一個非常簡單的使用者任務，它輸出訊息後進入無限迴圈。在實際的多任務系統中，這裡會是任務的主要執行邏輯。

### os_main - 主函式

```c
int os_main(void) {
    lib_puts("OS start\n");
    
    // 初始化任務上下文
    ctx_task.ra = (reg_t) user_task0;                    // 任務的返回位址
    ctx_task.sp = (reg_t) &task0_stack[STACK_SIZE-1];    // 任務的堆疊頂端
    
    // 切換到使用者任務
    sys_switch(&ctx_os, &ctx_task);
    
    // 這行理論上不會執行到，因為任務是无限循环
    return 0;
}
```

### 執行流程分析

1. 系統啟動，hart 0 執行 `_start`
2. `_start` 跳轉到 `os_main()`
3. `os_main()` 輸出 "OS start"
4. 初始化 `ctx_task`:
   - `ra` = `user_task0` 函式位址
   - `sp` = `task0_stack` 陣列的最高位址
5. 呼叫 `sys_switch(&ctx_os, &ctx_task)`
6. 組合語言保存 `ctx_os` (OS 的 ra, sp, s0-s11)
7. 組合語言恢復 `ctx_task` 的 ra, sp, s0-s11
8. 執行 `ret`，跳轉到 `user_task0`
9. `user_task0` 輸出訊息，進入无限循环
10. 如果任務要返回 OS，需要再次呼叫 `sys_switch` 保存任務狀態並恢復 OS 狀態

## 編譯與執行

### 編譯指令

```sh
make clean
make
```

編譯命令：
```
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima -mabi=ilp32 -T os.ld -o os.elf start.s sys.s lib.c os.c
```

注意這次需要編譯更多檔案：
- `start.s`: 啟動碼
- `sys.s`: 上下文切換 assembly
- `lib.c`: 標準輸출函式庫
- `os.c`: OS 核心邏輯

### 執行指令

```sh
make qemu
```

### 預期輸出

```
OS start
Task0: Context Switch Success !
```

## 上下文切換的深入理解

### 堆疊的角色

堆疊在上下文切換中扮演關鍵角色：
- 每個任務有自己的堆疊
- 函式呼叫時，返回位址和局部變數都放在堆疊上
- 暫存器保存時，這些值實際上是保存在任務的堆疊上

### 返回位址的雙重用途

在本階段中，`ra` 暫存器有雙重用途：
1. **函式返回位址**: 正常的函式呼叫返回點
2. **任務入口點**: 任務開始執行的位址

這是因為我們在初始化任務上下文時，將 `ra` 設置為任務函式的位址，所以 `sys_switch` 恢復上下文後執行 `ret` 就會跳轉到任務函式。

### 與真實 OS 的差異

真實的作業系統實現上下文切換時還會考慮：
- 完整的暫存器保存 (包括所有通用暫存器)
- 浮點暫存器保存 (如果使用了浮點運算)
- 特權模式切換 (從 kernel 切換到 user)
- 記憶體管理單元 (MMU) 上下文
- 裝置狀態保存

本專案簡化了這些內容，專注於核心概念。

## 重要概念まとめ

### 1. 上下文切換的本質

上下文切換本質上就是：
1. 保存當前 CPU 狀態到記憶體
2. 從記憶體恢復另一個任務的 CPU 狀態
3. 繼續執行恢復後的任務

這與函式呼叫有本質區別：函式呼叫是「保存返回點然後執行新函式」，而上下文切換是「保存整個執行狀態然後執行另一個任務」。

### 2. 同步 vs 異步切換

本階段實現的是**同步**上下文切換：
- 切換發生在 OS 明確呼叫 `sys_switch` 時
- 任務主動放棄 CPU 控制權

下一課的定時器中斷將實現**異步**（搶先式）上下文切換：
- 切換由硬體中斷觸發
- 任務可能在任何時候被強制切換

### 3. 堆疊切換

在上下文切換過程中，`sp` (堆疊指標) 的切換是最關鍵的步驟之一：
- 切換前：使用 OS 的堆疊
- 切換後：使用任務的堆疊

這確保了每個任務的函式呼叫和局部變數都保存在各自獨立的堆疊空間中。

## 下一步

下一課 [[03-Multi-Tasking]] 將基於本階段的上下文切換，實現完整的多任務管理系統，支援多個任務的創建、排程和執行。

## 相關資源

- RISC-V Calling Convention: https://riscv.org/abi/
- xv6-riscv context switch: https://github.com/mit-pdos/xv6-riscv
- 深入理解上下文切換: https://en.wikipedia.org/wiki/Context_switch
