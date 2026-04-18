# RISC-V CSR 暫存器

## 概述

控制與狀態暫存器 (Control and Status Registers, CSR) 是 RISC-V 架構中最重要的硬體資源之一，它們用於控制處理器的行為、監控系統狀態、以及處理中斷和異常。在 Machine Mode (M-mode) 下，CPU 可以存取所有的 CSR，這是作業系統核心開發的基礎。

本文件詳細介紹 RISC-V M-mode 中與本專案相關的 CSR，說明它們的功能、位元定義、以及在 mini-riscv-os 中的使用方式。

## RISC-V 特權等級與 CSR

### 特權等級概述

RISC-V 架構定義了三種特權等級：

| 特權等級 | 名稱 | 用途 | 可存取 CSR |
|----------|------|------|------------|
| U | User Mode | 使用者應用程式 | 僅用戶 CSR |
| S | Supervisor Mode | 作業系統核心 | 用戶 CSR + Supervisor CSR |
| M | Machine Mode | 硬體/韌體 | 所有 CSR |

本專案所有程式都在 M-mode 下執行，因此可以完全控制處理器和所有硬體資源。

### CSR 的編碼格式

每個 CSR 有一個唯一的 12 位元編碼：
- 位元 11-10：讀寫權限 (read-write = 11, read-only = 10, write-only = 01)
- 位元 9-8：特權等級 (00 = User, 01 = Supervisor, 11 = Machine)
- 位元 7-0：CSR 編號

例如：
- mstatus: 0x300 (0011 0000 0000)
- mie: 0x304 (0011 0000 0100)
- mtvec: 0x305 (0011 0000 0101)

## 核心 CSR 詳解

### mhartid - Hart ID 暫存器

**暫存器編號**: 0xF14

**功能**: 識別目前執行所在的硬體執行緒 (Hart)。這是一個唯讀暫存器，在多核心系統中每個 hart 有唯一的 ID。

**在 mini-riscv-os 中的使用**:

```c
static inline reg_t r_mhartid() {
    reg_t x;
    asm volatile("csrr %0, mhartid" : "=r" (x));
    return x;
}
```

**使用場景**:
- 識別目前在哪個 CPU 核心執行
- 為每個 hart 配置獨立的堆疊
- 初始化每個 hart 的定時器

### mstatus - Machine Status 暫存器

**暫存器編號**: 0x300

**功能**: 控制處理器的全局狀態，包括中斷使能和特權模式。

**位元定義**:

| 位元 | 名稱 | 描述 |
|------|------|------|
| 0 | UIE | User Mode 中斷使能 |
| 3 | MIE | Machine Mode 中斷使能 (最常用) |
| 4-7 | Reserved | 保留 |
| 11-12 | MPP | Previous Privilege Mode (前一個特權模式) |
| 13 | MPIE | Previous MIE (保存之前的中斷狀態) |

**常數定義**:

```c
#define MSTATUS_MIE (1 << 3)    // Machine Interrupt Enable
#define MSTATUS_MPP_M (3 << 11) // Previous Mode = Machine
#define MSTATUS_MPP_S (1 << 11) // Previous Mode = Supervisor  
#define MSTATUS_MPP_U (0 << 11) // Previous Mode = User
```

**在 mini-riscv-os 中的使用**:

```c
// 讀取 mstatus
static inline reg_t r_mstatus() {
    reg_t x;
    asm volatile("csrr %0, mstatus" : "=r" (x));
    return x;
}

// 寫入 mstatus (啟用中斷)
static inline void w_mstatus(reg_t x) {
    asm volatile("csrw mstatus, %0" : : "r" (x));
}

// 啟用 Machine Mode 中斷
w_mstatus(r_mstatus() | MSTATUS_MIE);
```

### mie - Machine Interrupt Enable 暫存器

**暫存器編號**: 0x304

**功能**: 控制在 M-mode 下各種類型中斷的使能狀態。

**位元定義**:

| 位元 | 名稱 | 描述 |
|------|------|------|
| 3 | MSIE | Machine Software Interrupt Enable (軟體中斷) |
| 7 | MTIE | Machine Timer Interrupt Enable (定時器中斷) |
| 11 | MEIE | Machine External Interrupt Enable (外部中斷) |

**常數定義**:

```c
#define MIE_MEIE (1 << 11) // External Interrupt
#define MIE_MTIE (1 << 7)  // Timer Interrupt
#define MIE_MSIE (1 << 3)  // Software Interrupt
```

**在 mini-riscv-os 中的使用**:

```c
// 讀取 mie
static inline reg_t r_mie() {
    reg_t x;
    asm volatile("csrr %0, mie" : "=r" (x));
    return x;
}

// 寫入 mie
static inline void w_mie(reg_t x) {
    asm volatile("csrw mie, %0" : : "r" (x));
}

// 啟用定時器中斷
w_mie(r_mie() | MIE_MTIE);
```

### mtvec - Machine Trap Vector 暫存器

**暫存器編號**: 0x305

**功能**: 儲存中斷和異常處理常式的入口位址。當任何陷阱 (trap) 發生時，CPU 會自動跳轉到此位址。

**位元定義**:

| 位元 | 描述 |
|------|------|
| 1-0 | MODE (0 = Direct, 1 = Vectored) |
| 63-2 | BASE (基址，必須對齊 4 位元組) |

**MODE 選項**:
- **Direct Mode (0)**: 所有陷阱都跳轉到 BASE 指定的位址
- **Vectored Mode (1)**: 不同類型的陷阱跳轉到不同的向量

**在 mini-riscv-os 中的使用**:

```c
static inline void w_mtvec(reg_t x) {
    asm volatile("csrw mtvec, %0" : : "r" (x));
}

// 設置中斷向量
w_mtvec((reg_t)sys_timer);
```

### mepc - Machine Exception Program Counter 暫存器

**暫存器編號**: 0x341

**功能**: 儲存陷阱發生時的程式計數器，用於在陷阱處理完成後返回到被中斷的位置。

**特性**:
- 可讀可寫
- 寫入時可修改返回位址
- 在 M-mode 下為 64 位元 (rv64) 或 32 位元 (rv32)

**在 mini-riscv-os 中的使用**:

```c
static inline reg_t r_mepc() {
    reg_t x;
    asm volatile("csrr %0, mepc" : "=r" (x));
    return x;
}

static inline void w_mepc(reg_t x) {
    asm volatile("csrw mepc, %0" : : "r" (x));
}
```

### mcause - Machine Cause 暫存器

**暫存器編號**: 0x342

**功能**: 儲存陷阱的原因，用於識別發生的是中斷還是異常，以及具體的類型。

**位元定義**:

| 位元 | 描述 |
|------|------|
| 63 | Interrupt (1 = 中斷, 0 = 異常) |
| 62-0 | Exception Code (原因編碼) |

**常見的 Exception Code**:

| Interrupt=1 | Exception Code | 原因 |
|-------------|----------------|------|
| 是 | 0 | Machine Software Interrupt |
| 是 | 1 | Reserved |
| 是 | 7 | Machine Timer Interrupt |
| 是 | 11 | Machine External Interrupt |
| 否 | 0 | Instruction Misaligned |
| 否 | 1 | Instruction Access Fault |
| 否 | 2 | Illegal Instruction |
| 否 | 3 | Breakpoint |
| 否 | 4 | Load Address Misaligned |
| 否 | 5 | Load Access Fault |
| 否 | 6 | Store/AMO Address Misaligned |
| 否 | 7 | Store/AMO Access Fault |
| 否 | 8 | Environment Call from U-mode |
| 否 | 11 | Environment Call from M-mode |

**在 mini-riscv-os 中的使用**:

```c
static inline reg_t r_mcause() {
    reg_t x;
    asm volatile("csrr %0, mcause" : "=r" (x));
    return x;
}

// 檢查是否為定時器中斷
if (r_mcause() == 0x80000007) {
    // 定時器中斷處理
}
```

### mscratch - Machine Scratch 暫存器

**暫存器編號**: 0x340

**功能**: 一個通用的 Scratch 暫存器，通常用於陷阱處理過程中臨時儲存資料。

**使用場景**:
- 在陷阱處理開始時保存某些暫存器
- 作為不同陷阱處理階段之間的資料傳遞

**在 mini-riscv-os 中的使用**:

```c
static inline void w_mscratch(reg_t x) {
    asm volatile("csrw mscratch, %0" : : "r" (x));
}
```

## CSR 操作的組合語言語法

### 讀取 CSR

```assembly
# 讀取 mstatus 到 t0
csrr t0, mstatus

# 讀取 mhartid 到 a0
csrr a0, mhartid
```

### 寫入 CSR

```assembly
# 將 t0 的值寫入 mstatus
csrw mstatus, t0

# 將立即數寫入 mtvec
li t0, 0x80000000
csrw mtvec, t0
```

### 讀取並修改

```assembly
# 讀取 mstatus，設定 MIE 位元
csrr t0, mstatus
ori t0, t0, 0x8   # 設定位元 3
csrw mstatus, t0
```

## 中斷處理的完整流程

### 1. 初始化階段

```c
void timer_init() {
    int id = r_mhartid();
    
    // 設置定時器比較值
    *(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
    
    // 設置中斷向量
    w_mtvec((reg_t)sys_timer);
    
    // 啟用全局中斷
    w_mstatus(r_mstatus() | MSTATUS_MIE);
    
    // 啟用定時器中斷
    w_mie(r_mie() | MIE_MTIE);
}
```

### 2. 中斷發生時

1. CPU 完成目前指令的執行
2. 設定 mepc = 下一條指令的位址
3. 設定 mcause = 中斷原因
4. 設定 mstatus.MPIE = mstatus.MIE (保存之前的中斷狀態)
5. 設定 mstatus.MIE = 0 (禁用中斷)
6. 跳轉到 mtvec 指定的位址

### 3. 中斷處理常式

```assembly
.align 4
.global sys_timer

sys_timer:
    # 保存上下文 (簡化版本)
    # 調用 C 語言處理常式
    call timer_handler
    # 返回到被中斷的程式
    mret
```

### 4. mret 指令

`mret` 是 Machine Mode Return 指令，它：
1. 從 mstatus.MPIE 恢復 mstatus.MIE
2. 從 mstatus.MPP 恢復特權模式
3. 跳轉到 mepc 指定的位址

## 與定時器相關的記憶體映射暫存器

### CLINT 記憶體映射

CLINT (Core-Local Interrupt Controller) 不是 CSR，而是一組記憶體映射的暫存器：

| 位址 | 暫存器 | 描述 |
|------|--------|------|
| 0x2000000 + 0xBFF8 | MTIME | 全域時間計數器 (64-bit) |
| 0x2000000 + 0x4000 + 4*hartid | MTIMECMP | 每個 hart 的比較值 |

### 使用方式

```c
#define CLINT 0x2000000
#define CLINT_MTIMECMP(hartid) (CLINT + 0x4000 + 4*(hartid))
#define CLINT_MTIME (CLINT + 0xBFF8)

// 讀取目前時間
uint64_t time = *(uint64_t*)CLINT_MTIME;

// 設置下次中斷時間
*(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
```

## 重要概念まとめ

### 1. CSR 操作的原子性

CSR 讀寫是原子操作，不需要額外的同步機制。這是 RISC-V 架構的設計保證。

### 2. 特權模式切換

當發生陷阱時，CPU 會自動切換到 M-mode，並保存之前的特權模式到 mstatus.MPP。

### 3. 中斷使能的層次

中斷使能涉及多個層次：
- **全局**: mstatus.MIE 必須為 1
- **局部**: mie 中對應的位元必須為 1
- **硬體**: 定時器必須設置 MTIMECMP

只有三個層次都滿足，中斷才會發生。

### 4. 中斷嵌套

本專案默認不啟用中斷嵌套，這意味著：
- 當處理一個中斷時，其他中斷會被阻塞
- 簡化了實現，避免了堆疊管理的複雜性

如果需要啟用中斷嵌套，必須在處理常式中保存完整上下文並使用獨立的中斷堆疊。

## 相關資源

- RISC-V Privileged Architecture Manual: https://riscv.org/specifications/
- RISC-V ISA Manual: https://riscv.org/technical/
- QEMU RISC-V: https://www.qemu.org/docs/master/system/riscv.html

## 相關頁面

- [[04-Timer-Interrupt]] - 定時器中斷實際應用
- [[risc-v-registers]] - RISC-V 暫存器約定
