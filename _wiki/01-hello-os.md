# 01-Hello-OS

## 概述

這是 mini-riscv-os 的第一個階段，實現一個最基礎的開機作業系統，能夠在 QEMU 模擬器中執行並輸出 "Hello OS!" 到終端機。這個階段雖然簡單，但涵蓋了 RISC-V 作業系統開發的核心概念：啟動流程、記憶體配置、堆疊設定，以及 UART 序列輸出。

## 硬體環境

### QEMU virt 機器

本專案使用 QEMU 模擬 RISC-V virt 虛擬機器，其記憶體映射如下：

```
0x00000000 - 0xFFFFFFFF : 記憶體空間
0x00000000 - 0x0FFFFFFF : ROM/Flash (實際未使用)
0x10000000 - 0x1000FFFF : UART (序列埠)
0x2000000  - 0x203FFFFF : CLINT (Core-Local Interrupt Controller)
0x40000000 - 0x41FFFFFF : PLIC (Platform-Level Interrupt Controller)
0x80000000 - 0xFFFFFFFF : RAM
```

### UART (序列埠)

UART (Universal Asynchronous Receiver/Transmitter) 是 embedded 系統中最常見的輸出裝置。在 QEMU virt 機器中，UART0 的基底位址是 0x10000000。

| 位址 | 暫存器 | 簡稱 | 描述 |
|------|--------|------|------|
| 0x10000000 | THR | Transmitter Holding Register | 傳送資料緩衝區 |
| 0x10000001 | RBR | Receiver Buffer Register | 接收資料緩衝區 |
| 0x10000005 | LSR | Line Status Register | 線路狀態暫存器 |

LSR 暫存器的位元 5 (TX FIFO Empty) 和位元 6 (Transmitter Empty) 用於確認傳送是否完成。當這些位元為 1 時，表示 UART 傳送緩衝區为空，可以發送下一個字元。

## 啟動流程

### start.s - 組合語言啟動碼

RISC-V 系統啟動時，處理器從位址 0x00000000 開始執行。在本專案中，我們使用 linker script 將 `_start` 符號配置在 ROM 位置，讓 CPU 一開始就執行我們的啟動碼。

```assembly
.equ STACK_SIZE, 8192

.global _start

_start:
    # 設定每個 hart (硬體執行緒) 的堆疊
    csrr t0, mhartid        # 讀取目前 hart 的 ID
    slli t0, t0, 10        # 將 hart ID 左移 10 位元 (乘以 1024)
    la   sp, stacks + STACK_SIZE  # 載入堆疊空間的起始位址
    add  sp, sp, t0        # 根據 hart ID 移動到該 hart 的堆疊位置
    
    # Hart 0 執行 OS，其餘 hart 進入待機
    csrr a0, mhartid       # 再次讀取 hart ID
    bnez a0, park          # 如果不是 hart 0，跳到 park 標籤
    
    j    os_main           # Hart 0 跳轉到 C 語言的 os_main

park:
    wfi                    # Wait For Interrupt - 進入低功耗待機
    j park                 # 無限迴圈

stacks:
    .skip STACK_SIZE * 4   # 配置 4 個 hart 的堆疊空間 (8192 * 4 = 32KB)
```

### 堆疊配置解析

每個 hart 需要獨立的堆疊空間，避免任務之間的堆疊資料相互覆蓋。我們配置了 8KB 的堆疊給每個 hart，總共 32KB (4 個 harts × 8KB)。

計算方式：
- Hart 0: sp = stacks + 8192
- Hart 1: sp = stacks + 8192 + 1024 = stacks + 9216
- Hart 2: sp = stacks + 8192 + 2048 = stacks + 10240
- Hart 3: sp = stacks + 8192 + 3072 = stacks + 11264

### mhartid CSR

`mhartid` 是 RISC-V Machine Mode 的 CSR (Control and Status Register)，用於識別目前在哪個硬體執行緒上執行。這在多核心系統中特別重要，可以讓每個核心使用不同的堆疊。

## os.c - C 語言核心

### UART 輸出函式

```c
#define UART        0x10000000
#define UART_THR    (uint8_t*)(UART+0x00)
#define UART_LSR    (uint8_t*)(UART+0x05)
#define UART_LSR_EMPTY_MASK 0x40

int lib_putc(char ch) {
    // 等待 UART 傳送緩衝區為空
    while ((*UART_LSR & UART_LSR_EMPTY_MASK) == 0);
    // 寫入字元到 THR
    return *UART_THR = ch;
}

void lib_puts(char *s) {
    while (*s) lib_putc(*s++);
}
```

這些函式展示了記憶體映射 I/O (Memory-Mapped I/O) 的概念。UART 裝置不是透過專屬指令存取，而是像存取記憶體一樣透過指標 dereference 來操作。

### lib_delay - 簡單延遲函式

為了支援後續的多任務練習，我們在 01 階段就加入了一個簡單的 busy-wait 延遲函式：

```c
void lib_delay(int ticks) {
    volatile int i = 0;
    while (i++ < ticks);
}
```

這是一個簡單的忙碌等待實作，適合在沒有作業系統的情況下使用。

### os_main - 主函式

```c
int os_main(void) {
    lib_puts("Hello OS!\n");
    while (1) {}  // 無限迴圈
    return 0;
}
```

這是作業系統的核心入口點。在真實的作業系統中，這裡會初始化各種子系統、驅動程式，然後開始執行使用者任務。

## Linker Script - os.ld

Linker script 決定了輸出執行檔的記憶體配置：

```
MEMORY
{
    ram (wx!al) : ORIGIN = 0x80000000, LENGTH = 128M
}

ENTRY(_start)

SECTIONS
{
    .text : { *(.text) } > ram
    .rodata : { *(.rodata) } > ram
    .data : { *(.data) } > ram
    .bss : { *(.bss) } > ram
}
```

所有程式碼和資料都被放置在 RAM 中 (起始位址 0x80000000)，這是 QEMU virt 機器預設的 RAM 位置。

## 編譯與執行

### 編譯指令

```sh
make clean
make
```

編譯命令使用 riscv64-unknown-elf-gcc：
```
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima -mabi=ilp32 -T os.ld -o os.elf start.s os.c
```

參數說明：
- `-nostdlib`: 不連結標準函式庫
- `-fno-builtin`: 不使用內建函式
- `-mcmodel=medany`: 使用中等程式碼模型
- `-march=rv32ima`: 目標架構 rv32ima (RISC-V 32-bit Integer + Multiply + Atomics)
- `-mabi=ilp32`: ABI 為 ILP32 (int/long/pointer 都是 32 位元)
- `-T os.ld`: 使用 os.ld 作為 linker script

### 執行指令

```sh
make qemu
```

這會啟動 QEMU：
```
qemu-system-riscv32 -nographic -smp 4 -machine virt -bios none -kernel os.elf
```

參數說明：
- `-nographic`: 不使用圖形介面，使用終端機
- `-smp 4`: 模擬 4 個 CPU 核心
- `-machine virt`: 使用 virt 機器類型
- `-bios none`: 不使用 BIOS，直接從 kernel 啟動
- `-kernel os.elf`: 指定核心映像檔

## 輸出結果

執行後應該看到：
```
Hello OS!
```

## 重要概念まとめ

### 1. RISC-V 執行模式

RISC-V 有三種特權等級：
- **Machine Mode (M-mode)**: 最高權限，可以存取所有 CSR 和硬體
- **Supervisor Mode (S-mode)**: 作業系統核心使用
- **User Mode (U-mode)**: 使用者應用程式使用

本專案所有程式都在 M-mode 下執行，簡化了開發過程。

### 2. Hart vs Core

在 RISC-V 術語中，"hart" (hardware thread) 是硬體執行緒的縮寫。在多核心系統中，每個核心就是一個 hart。術語 "hart" 比 "core" 更精確，因為它強調了每個執行緒都是獨立的執行單元。

### 3. 記憶體映射 I/O

記憶體映射 I/O 是一种將硬體裝置暫存器映射到記憶體位址空間的技術。軟體可以通過讀寫特定記憶體位址來與硬體裝置互動，而不需要特殊的 I/O 指令。這是嵌入式系統中常見的做法。

### 4. 組合語言與 C 語言的橋接

在作業系統開發中，組合語言用於：
- 系統啟動和初始化
- 上下文切換
- 存取特殊暫存器 (CSR)

C 語言則用於實作更高層次的邏輯。這種混合開發模式是作業系統開發的常見做法。

## 下一步

下一課 [[02-Context-Switch]] 將介紹如何實現手動的上下文切換，讓我們能夠在多個任務之間切換執行。

## 相關資源

- QEMU RISC-V: https://www.qemu.org/docs/master/system/riscv.html
- RISC-V ISA Manual: https://riscv.org/technical/specifications/
- RISC-V ABI: https://github.com/riscv/riscv-elf-psabi-doc
