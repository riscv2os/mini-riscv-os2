# RISC-V 暫存器

## 概述

RISC-V 架構定義了 32 個通用用途暫存器 (General Purpose Registers)，它們是程式執行時最基本的資料儲存單元。了解這些暫存器的用途、命名和呼叫約定是進行組合語言編程和作業系統開發的基礎。

本文件詳細介紹 RISC-V 的暫存器組織、ABI 命名、呼叫約定，以及在上下文切換中需要保存的暫存器。

## 暫存器總覽

### 暫存器列表

RISC-V 有 32 個通用用途暫存器 (x0-x31)：

| 暫存器編號 | ABI 名稱 | 描述 | 保存者 |
|------------|----------|------|--------|
| x0 | zero | 常數 0，永遠為 0 | - |
| x1 | ra | Return Address (返回位址) | Caller |
| x2 | sp | Stack Pointer (堆疊指標) | Callee |
| x3 | gp | Global Pointer (全域指標) | - |
| x4 | tp | Thread Pointer (執行緒指標) | - |
| x5 | t0 | 臨時暫存器 0 | Caller |
| x6 | t1 | 臨時暫存器 1 | Caller |
| x7 | t2 | 臨時暫存器 2 | Caller |
| x8 | s0 / fp | Saved 0 / Frame Pointer | Callee |
| x9 | s1 | Saved 1 | Callee |
| x10 | a0 | Function Argument 0 / Return Value 0 | Caller |
| x11 | a1 | Function Argument 1 / Return Value 1 | Caller |
| x12 | a2 | Function Argument 2 | Caller |
| x13 | a3 | Function Argument 3 | Caller |
| x14 | a4 | Function Argument 4 | Caller |
| x15 | a5 | Function Argument 5 | Caller |
| x16 | a6 | Function Argument 6 | Caller |
| x17 | a7 | Function Argument 7 | Caller |
| x18 | s2 | Saved 2 | Callee |
| x19 | s3 | Saved 3 | Callee |
| x20 | s4 | Saved 4 | Callee |
| x21 | s5 | Saved 5 | Callee |
| x22 | s6 | Saved 6 | Callee |
| x23 | s7 | Saved 7 | Callee |
| x24 | s8 | Saved 8 | Callee |
| x25 | s9 | Saved 9 | Callee |
| x26 | s10 | Saved 10 | Callee |
| x27 | s11 | Saved 11 | Callee |
| x28 | t3 | 臨時暫存器 3 | Caller |
| x29 | t4 | 臨時暫存器 4 | Caller |
| x30 | t5 | 臨時暫存器 5 | Caller |
| x31 | t6 | 臨時暫存器 6 | Caller |

## 暫存器分類

### 特殊用途暫存器

- **x0 (zero)**: 永遠為 0 的暫存器，用於：
  - 產生常數 0: `addi x1, zero, 5` -> x1 = 5
  - 忽略函式返回值: `call foo; mv a0, zero` -> 丟棄返回值
  
- **x1 (ra)**: 返回位址暫存器
  - 儲存函式返回後要執行的位址
  - 使用 `jal` 指令時自動設置
  - 使用 `ret` (即 `jr ra`) 返回
  
- **x2 (sp)**: 堆疊指標
  - 指向目前堆疊的頂端
  - 必須在函式呼叫期間保持不變 (Callee-saved)
  
- **x3 (gp)**: 全域指標
  - 指向資料段的中央位置
  - 用於快速存取全域變數
  
- **x4 (tp)**: 執行緒指標
  - 用於執行緒區域儲存 (Thread-Local Storage)
  - 在簡單程式中通常不使用

### Caller-saved 暫存器 (易失性)

這些暫存器被稱為「Caller-saved」或「Temporary」：
- **t0-t6** (x5-x7, x28-x31): 臨時暫存器
- **a0-a7** (x10-x17): 函式引數和返回值

特性：
- 函式呼叫時可以被覆蓋
- 呼叫者 (caller) 不能依賴這些值在呼叫後保持不變
- 如果需要保持值，呼叫者必須自行保存

### Callee-saved 暫存器 (非易失性)

這些暫存器被稱為「Callee-saved」或「Saved」：
- **s0-s11** (x8-x9, x18-x27): 保存暫存器

特性：
- 被呼叫的函式 (callee) 必須確保這些值在返回時不變
- 如果需要使用，函式必須先保存，使用後再恢復
- 這是上下文切換時需要保存的暫存器

## RISC-V 呼叫約定

### 函式呼叫語義

當一個函式呼叫另一個函式時：

**呼叫前 (Caller)**:
1. 將引數放入 a0-a7
2. 保存 Caller-saved 暫存器 (如果需要)
3. 執行 `jal` 指令，跳轉並設置 ra

**呼叫後 (Callee)**:
1. 分配堆疊空間
2. 保存 Callee-saved 暫存器 (如果需要使用)
3. 執行函式主體
4. 將返回值放入 a0-a1
5. 恢復 Callee-saved 暫存器
6. 執行 `ret` 返回

**返回後 (Caller)**:
1. 從 a0-a1 讀取返回值
2. 恢復 Caller-saved 暫存器 (如果之前保存了)

### 參數傳遞

最多 8 個引數可以透過暫存器傳遞：
- a0-a7 用於引數
- 超過 8 個的引數透過堆疊傳遞

```c
// C 程式
void foo(int a, int b, int c, int d);

// 組合語言
li a0, 1      // a = 1
li a1, 2      // b = 2
li a2, 3      // c = 3
li a3, 4      // d = 4
call foo
```

### 返回值

- 單個返回值：a0
- 雙個返回值：a0 (低位), a1 (高位)

```c
// C 程式
int foo(void);

// 組合語言
call foo
# 返回值在 a0 中
```

## 上下文切換中的暫存器

### 為什麼需要保存暫存器？

在上下文切換時，我們需要保存任務的完整狀態，這樣才能在稍後恢復並繼續執行。保存的資料稱為「上下文」(Context)。

### 需要保存的暫存器

在 mini-riscv-os 中，我們保存以下暫存器：

| 暫存器 | 用途 | 保存原因 |
|--------|------|----------|
| ra | 返回位址 | 任務恢復後需要知道從哪裡繼續執行 |
| sp | 堆疊指標 | 每個任務有獨立的堆疊 |
| s0-s11 | 保存暫存器 | 這些暫存器必須在函式間保持 |

### 上下文結構定義

```c
#include <stdint.h>

typedef uint32_t reg_t;  // 32 位元

struct context {
    reg_t ra;   // x1 - 返回位址
    reg_t sp;   // x2 - 堆疊指標
    
    // s0-s11 (x8-x9, x18-x27)
    reg_t s0;
    reg_t s1;
    reg_t s2;
    reg_t s3;
    reg_t s4;
    reg_t s5;
    reg_t s6;
    reg_t s7;
    reg_t s8;
    reg_t s9;
    reg_t s10;
    reg_t s11;
};
```

### 組合語言實現

```assembly
# void sys_switch(struct context *ctx_old, struct context *ctx_new)
# a0 = ctx_old
# a1 = ctx_new

.global sys_switch

sys_switch:
    # 保存目前任務的上下文到 ctx_old
    
    # 保存返回位址
    sd ra, 0(a0)
    
    # 保存堆疊指標
    addi t0, sp, 0
    sd t0, 8(a0)
    
    # 保存 Callee-saved 暫存器
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
    
    # 切換到新任務
    ret
```

### 為什麼不保存所有暫存器？

簡化實現：
- Caller-saved 暫存器在函式呼叫時本來就可能被覆蓋
- 我們只保存 Callee-saved，這是最少需要保存的集合

在更完整的實現中，可能會保存：
- a0-a7 (如果任務依賴這些值)
- 其他上下文的元資料

## 堆疊操作

### 函式呼叫與堆疊

當函式被呼叫時，堆疊的變化：

```c
void foo() {
    int local = 10;  // 局部變數
    // ...
}
```

對應的組合語言：
```assembly
# 進入 foo
addi sp, sp, -8   # 分配堆疊空間 (2 個 4 位元組)
sw s0, 0(sp)      # 保存 s0
sw ra, 4(sp)      # 保存 ra

# 函式主體
li s0, 10         # local = 10 (使用 s0)

# 返回前
lw s0, 0(sp)      # 恢復 s0
lw ra, 4(sp)      # 恢復 ra
addi sp, sp, 8     # 釋放堆疊空間
ret               # 返回
```

### 堆疊增長方向

RISC-V 的堆疊向低位址增長：
- `addi sp, sp, -8` = 分配 8 位元組
- `addi sp, sp, 8` = 釋放 8 位元組

## 32 位元 vs 64 位元

### 32 位元模式 (rv32)

- 暫存器寬度：32 位元
- `reg_t` = `uint32_t`
- 指令：`sw`, `lw`, `addi` (32 位元)

### 64 位元模式 (rv64)

- 暫存器寬度：64 位元
- `reg_t` = `uint64_t`
- 指令：`sd`, `ld`, `addiw` (64 位元)

### 主要差異

| 特性 | 32 位元 | 64 位元 |
|------|---------|---------|
| 指標大小 | 4 位元組 | 8 位元組 |
| long 大小 | 4 位元組 | 8 位元組 |
| 堆疊對齊 | 4 位元組 | 8 位元組 |
| 指令 | sw, lw | sd, ld |

## 重要概念まとめ

### 1. Caller-saved vs Callee-saved

**Caller-saved** (t0-t6, a0-a7):
- 函式可以自由使用，覆蓋它們
- 如果需要保持值，呼叫者必須自己保存

**Callee-saved** (s0-s11):
- 被呼叫的函式必須保持它們的值
- 如果需要使用，必須先保存後再恢復

### 2. 暫存器的雙重角色

RISC-V 暫存器有多種用途：
- 有些有特殊用途 (ra, sp, gp, tp)
- 其餘是通用暫存器
- 同一個暫存器在不同上下文中用途不同

### 3. 上下文切換的核心

上下文切換的核心是：
- 保存：將 Callee-saved 暫存器保存到記憶體
- 恢復：從記憶體恢復到 Callee-saved 暫存器
- 切換：改變堆疊指標和返回位址

### 4. 呼叫約定的意義

呼叫約定確保不同編譯器編譯的程式可以相互呼叫：
- 定義了引數和返回值的傳遞方式
- 定義了哪些暫存器需要保存
- 使混合語言編程成為可能

## 相關資源

- RISC-V ISA Manual: https://riscv.org/specifications/
- RISC-V ELF psABI: https://github.com/riscv/riscv-elf-psabi-doc
- Calling Convention: https://riscv.org/abi/

## 相關頁面

- [[02-Context-Switch]] - 上下文切換實際應用
- [[risc-v-csrs]] - RISC-V CSR 暫存器
