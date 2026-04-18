# Mini-RISC-V OS Wiki

一個從零構建的 RISC-V 作業系統教學專案，包含 9 個階段，從基礎開機到多核心 64 位元系統。

## 概述

本專案實現了一個極簡的 RISC-V 作業系統，逐步構建從單核心到多核心、從 32 位元到 64 位元的作業系統核心。每個階段都有完整的實現和詳細的程式碼說明。

## 課程章節

| 章節 | 主題 | 描述 |
|------|------|------|
| [[01-hello-os]] | Hello OS | 基礎開機流程、UART 序列輸出、堆疊設定 |
| [[02-context-switch]] | Context Switch | 手動上下文切換、組合語言實現 |
| [[03-multi-tasking]] | Multi-Tasking | 合作式多任務、任務排程 |
| [[04-timer-interrupt]] | Timer Interrupt | 定時器中斷、CLINT、CSR 操作 |
| [[05-preemptive]] | Preemptive | 搶先式多任務、時間片輪詢 |
| [[06-mutex]] | Mutex | 互斥鎖、同步機制、臨界區 |
| [[07-multicore-32bit]] | Multicore 32bit | 32 位元多核心、SMP 架構 |
| [[08-multicore-64bit]] | Multicore 64bit | 64 位元 RISC-V、LP64 ABI |
| [[09-interrupt-isr]] | Interrupt ISR | ISR 框架、動態註冊、驅動程式 |

## 技術規格

- **架構**: RISC-V 32-bit (rv32ima) / 64-bit (rv64ima)
- **ABI**: ILP32 (32-bit) / LP64 (64-bit)
- **編譯器**: riscv64-unknown-elf-gcc
- **模擬器**: QEMU (riscv32/riscv64 virt machine)
- **特權等級**: Machine Mode (M-mode)

## 建置與執行

```sh
# 編譯
make clean
make

# 執行
make qemu
```

## 相關概念

| 概念 | 描述 |
|------|------|
| [[risc-v-csrs]] | RISC-V 控制與狀態暫存器 |
| [[risc-v-registers]] | RISC-V 暫存器約定與呼叫慣例 |

## 專案結構

```
mini-riscv-os/
├── 01-HelloOs/          # 第一階段：Hello OS
├── 02-ContextSwitch/     # 第二階段：上下文切換
├── 03-MultiTasking/      # 第三階段：多任務
├── 04-TimerInterrupt/     # 第四階段：定時器中斷
├── 05-Preemptive/         # 第五階段：搶先式排程
├── 06-Mutex/             # 第六階段：互斥鎖
├── 07-Multicore32bit/    # 第七階段：32 位元多核心
├── 08-Multicore64bit/    # 第八階段：64 位元多核心
├── 09-InterruptISR/      # 第九階段：中斷 ISR
└── _wiki/                # Wiki 文件
```

## 學習路徑

1. **基礎**: 01 → 02 → 03 (了解開機和任務管理)
2. **中斷**: 04 → 05 (理解中斷驅動的排程)
3. **同步**: 06 (學習任務同步)
4. **進階**: 07 → 08 → 09 (多核心和 ISR)

## 相關資源

- QEMU RISC-V: https://www.qemu.org/docs/master/system/riscv.html
- RISC-V ISA Manual: https://riscv.org/specifications/
- RISC-V ABI: https://github.com/riscv/riscv-elf-psabi-doc

---
*本 Wiki 根據 LLM Wiki 模式構建*
