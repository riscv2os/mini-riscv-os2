# 04-Timer-Interrupt

## 概述

這是 mini-riscv-os 的第四個階段，引入硬體定時器中斷 (Timer Interrupt) 的概念。定時器中斷是實現搶先式多任務 (Preemptive Multitasking) 的關鍵基礎設施，它允許作業系統在任務自願放棄 CPU 之前，強制性地搶佔 CPU 控制權並進行任務切換。

本階段不涉及多任務的完整實現，而是專注於定時器的初始化、設置中斷向量、以及處理定時器中斷。我們會看到定時器中斷如何週期性地觸發，並在每次中斷時執行處理常式。

## RISC-V 中斷架構

### 特權等級

RISC-V 架構定義了三種特權等級：

| 等級 | 名稱 | 用途 |
|------|------|------|
| U | User Mode | 使用者應用程式 |
| S | Supervisor Mode | 作業系統核心 |
| M | Machine Mode | 硬體/韌體/嵌入式系統 |

本專案所有程式都在 Machine Mode (M-mode) 下執行，這是最高的特權等級，可以存取所有硬體資源。

### 中斷類型

RISC-V 支持三種中斷類型：

1. **Software Interrupt (軟體中斷)**: 由軟體觸發，通常用於跨核心訊號
2. **Timer Interrupt (定時器中斷)**: 由硬體定時器觸發
3. **External Interrupt (外部中斷)**: 來自外部裝置，如 UART、網路等

### 控制與狀態暫存器 (CSR)

在 M-mode 下，主要的中斷相關 CSR 有：

| CSR | 名稱 | 功能 |
|-----|------|------|
| mstatus | Machine Status | 全域中斷使能 (MIE 位元) |
| mie | Machine Interrupt Enable | 各類中斷的個別使能 |
| mtvec | Machine Trap Vector | 中斷/異常處理常式位址 |
| mepc | Machine Exception PC | 中斷發生後的返回位址 |
| mcause | Machine Cause | 中斷原因編碼 |
| mhartid | Hart ID | 目前 hart 編號 |

## CLINT - Core-Local Interrupt Controller

### 什麼是 CLINT？

CLINT 是 RISC-V 系統中的核心區域中斷控制器，負責處理以下功能：
- 提供定時器中斷
- 提供軟體中斷
- 每個 hart (CPU 核心) 有獨立的定時器

### 記憶體映射

```
0x2000000           - CLINT 基底位址
0x2000000 + 0x4000  - MTIMECMP for hart 0
0x2000000 + 0x4004  - MTIMECMP for hart 1
...                 - 每個 hart 4 位元組
0x2000000 + 0xBFF8  - MTIME (全域時間計數器)
```

- **MTIME**: 一個 64 位元的計數器，由硬體自動遞增，代表自系統啟動以來的時脈週期數
- **MTIMECMP**: 每個 hart 的定時器比較暫存器。當 MTIME >= MTIMECMP 時，產生定時器中斷

### 定時器初始化流程

```c
void timer_init() {
    int id = r_mhartid();  // 獲取目前 hart ID
    
    // 設置下一次中斷時間
    *(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
    
    // 設置中斷向量
    w_mtvec((reg_t)sys_timer);
    
    // 啟用全域中斷
    w_mstatus(r_mstatus() | MSTATUS_MIE);
    
    // 啟用定時器中斷
    w_mie(r_mie() | MIE_MTIE);
}
```

讓我們逐步解釋這段程式碼：

1. **讀取 hart ID**: `r_mhartid()` 讀取目前 CPU 核心的 ID，用於配置該核心的定時器

2. **設置 MTIMECMP**: 這是 CLINT 的核心功能。我們將目前的 MTIME 值加上時間間隔 (interval)，得到未來中斷應該發生的時間點。這個值會被写入对应 hart 的 MTIMECMP 暂存器。

3. **設置中斷向量**: `w_mtvec()` 將中斷處理常式的位址寫入 mtvec CSR。當任何中斷或異常發生時，CPU 會自動跳轉到此位址執行。

4. **啟用全域中斷**: mstatus CSR 的 MIE (Machine Interrupt Enable) 位元必須設置為 1，才會響應任何中斷。

5. **啟用定時器中斷**: mie CSR 的 MTIE (Machine Timer Interrupt Enable) 位元必須設置為 1，才會響應定時器中斷。

## 中斷處理機制

### 中斷向量表

在 RISC-V 中，mtvec 可以配置為兩種模式：
- **Direct Mode**: 所有中斷都跳轉到同一個處理常式位址
- **Vectored Mode**: 不同類型的中斷跳轉到不同的處理常式

本專案使用 Direct Mode，所有中斷都跳轉到 `sys_timer` 函式。

### sys_timer 處理常式

```assembly
.align 4
.global sys_timer

sys_timer:
    # 這裡應該保存上下文
    # 但在本階段，我們只是簡單地調用 C 函式
    
    # 調用 timer_handler C 函式
    call timer_handler
    
    # 返回到被中斷的位置
    mret
```

注意這裡的 `mret` 指令：
- 它相當於 `jr mepc`
- 它使用 mepc CSR 中儲存的位址返回到被中斷的程式

### C 語言定時器處理常式

```c
static int timer_count = 0;

void timer_handler() {
    // 禁用定時器中斷，避免中斷嵌套
    w_mie(~((~r_mie()) | (1 << 7)));
    
    lib_printf("timer_handler: %d\n", ++timer_count);
    
    int id = r_mhartid();
    // 重新設置定時器中斷
    *(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
    
    // 重新啟用定時器中斷
    w_mie(r_mie() | MIE_MTIE);
}
```

### 為什麼需要禁用/重新啟用中斷？

在處理中斷時禁用中斷是重要的安全措施：
- 防止中斷處理常式被另一個中斷打斷
- 避免計數器更新 race condition
- 確保中斷處理的原子性

處理完成後，重新啟用中斷允許系統繼續響應後續的中斷。

## 完整的定時器配置

### 設定參數

```c
#define interval 10000000  // 大約 1 秒 (在 QEMU 中)
```

這個值的計算取決於：
- QEMU 模擬的 CPU 時脈
- 實際硬體的時脈

在 QEMU virt 中，時脈通常被模擬為 10MHz 左右，所以 10000000 週期大約是 1 秒。

### 初始化後的行為

1. `timer_init()` 被調用
2. 定時器中斷被使能
3. 經過 interval 週期後，產生定時器中斷
4. CPU 自動跳轉到 `sys_timer` (mtvec 指定的位址)
5. `sys_timer` 調用 C 函式 `timer_handler`
6. `timer_handler` 輸出計數值，重新設置定時器
7. 返回到被中斷的程式
8. 重複步驟 3

## 編譯與執行

### 編譯指令

```sh
make clean
make
```

編譯命令：
```
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima_zicsr -mabi=ilp32 -T os.ld -o os.elf start.s sys.s lib.c timer.c os.c
```

注意 `timer.c` 是新加入的檔案。

### 執行指令

```sh
make qemu
```

### 預期輸出

```
OS start
timer_handler: 1
timer_handler: 2
timer_handler: 3
timer_handler: 4
timer_handler: 5
...
```

每行代表一次定時器中斷，大約每秒一次。

## 深入理解 RISC-V 中斷機制

### mstatus CSR

mstatus 暫存器中與中斷相關的位元：

| 位元 | 名稱 | 功能 |
|------|------|------|
| 3 | MIE | Machine Interrupt Enable |
| 7 | MPIE | Previous MIE (用於保存前一個狀態) |
| 11-12 | MPP | Previous Privilege Mode |

### mie CSR

mie 暫存器中與中斷相關的位元：

| 位元 | 名稱 | 功能 |
|------|------|------|
| 3 | MSIE | Machine Software Interrupt Enable |
| 7 | MTIE | Machine Timer Interrupt Enable |
| 11 | MEIE | Machine External Interrupt Enable |

### mret 指令

`mret` 是 Machine Mode Return 指令，它：
1. 從 mstatus恢復 MIE 狀態 (MPIE -> MIE)
2. 從 mstatus 恢復特權模式 (MPP)
3. 跳轉到 mepc 指定的位址

### mcause CSR

mcause 暫存器記錄中斷原因：

| 值 | 意義 |
|----|------|
| 0 | 軟體中斷 |
| 1 | 保留 |
| ... | ... |
| 7 | 定時器中斷 |
| 11 | 外部中斷 |

當中斷發生時，mcause 會自動設置為對應的值。

## 重要概念まとめ

### 1. 中斷驅動 vs 輪詢

**中斷驅動 (Interrupt-driven)**:
- 硬體主動通知 CPU 有事件發生
- CPU 不需要持續檢查狀態
- 響應速度快
- 適合需要即時反應的系統

**輪詢 (Polling)**:
- CPU 持續檢查某個狀態
- 浪費 CPU 資源
- 響應時間取決於檢查頻率

本階段使用中斷驅動方式，這是現代作業系統的標準做法。

### 2. 中斷向量

中斷向量是處理中斷服務的入口點。在 RISC-V 中，mtvec CSR 儲存這個入口點位址。

設計考量：
- 簡單的 Direct Mode：所有中斷同一個入口
- Vectored Mode：不同中斷不同入口

本專案使用 Direct Mode，在入口處判斷是中斷還是異常，然後分發到相應的處理常式。

### 3. 中斷嵌套

中斷嵌套是指在處理一個中斷時，另一個中斷發生。

本專案默認不允許中斷嵌套，原因：
- 簡化實現
- 避免堆疊溢出風險
- 中斷處理常式應該盡快完成

如果需要支持中断嵌套，需要：
- 在處理常式中保存完整上下文
- 使用獨立的堆疊處理中斷

### 4. 時間解析度

定時器中斷的頻率決定了系統的時間解析度：
- 高頻率：更精確的時間測量，但開銷更大
- 低頻率：較低的開銷，但時間測量精度降低

實際選擇取決於應用需求：
- 即時系統需要高頻率
- 簡單的任務調度可以低頻率

## 下一步

下一課 [[05-Preemptive]] 將結合本階段的定時器中斷和第三階段的多任務系統，實現完整的搶先式多任務。這是作業系統最核心的功能之一。

## 相關資源

- RISC-V Privileged Architecture: https://riscv.org/specifications/
- CLINT specification: https://github.com/riscv/riscv-qemu/wiki
- RISC-V Interrupt Handling: https://riscv.org/tech/
