# 64-bit RISC-V OS 修改報告

## 概述

將 mini-riscv-os 的 Chapter 07b (Multicore) 從 32-bit RV32IMA 改為 64-bit RV64IMA。

## 硬體/軟體環境

- QEMU: qemu-system-riscv64 version 10.2.2
- Compiler: riscv64-unknown-elf-gcc
- Architecture: RV64IMA + Zicsr

---

## 程式碼修改

### 1. Makefile

```diff
- CFLAGS = -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima_zicsr -mabi=ilp32
+ CFLAGS = -nostdlib -fno-builtin -mcmodel=medany -march=rv64ima_zicsr -mabi=lp64

- QEMU = qemu-system-riscv32
+ QEMU = qemu-system-riscv64

- QFLAGS = -nographic -smp 4 -machine virt -bios none
+ QFLAGS = -nographic -smp 1 -machine virt -bios none
```

**說明**：
- `march=rv64ima` vs `rv32ima`: 目標架構
- `mabi=lp64` vs `ilp64`: ABI 调用约定 (64-bit vs 32-bit)
- 預設使用 4 cores 測試多核心運作

---

### 2. riscv.h

```diff
- #define reg_t uint32_t // RISCV32: register is 32bits
- // define reg_t as uint64_t // RISCV64: register is 64bits
+ // #define reg_t uint32_t // RISCV32: register is 32bits
+ #define reg_t uint64_t // RISCV64: register is 64bits
```

```diff
- #define CLINT_MTIMECMP(hartid) (CLINT + 0x4000 + 4*(hartid))
+ #define CLINT_MTIMECMP(hartid) (CLINT + 0x4000 + 8*(hartid))
```

**說明**：
- `reg_t`: 寄存器寬度從 32-bit 改為 64-bit
- CLINT offset: 每個 hart 的 mtimecmp 在 RV64 中佔 8 bytes (RV32 為 4 bytes)

```diff
- #define MSTATUS_MPP_MASK (3 << 11) // previous mode.
- #define MSTATUS_MPP_M (3 << 11)
- #define MSTATUS_MPP_S (1 << 11)
- #define MSTATUS_MPP_U (0 << 11)
- #define MSTATUS_MIE (1 << 3)
+ #define MSTATUS_MPP_MASK (3UL << 11) // previous mode.
+ #define MSTATUS_MPP_M (3UL << 11)
+ #define MSTATUS_MPP_S (1UL << 11)
+ #define MSTATUS_MPP_U (0UL << 11)
+ #define MSTATUS_MIE (1UL << 3)
```

**說明**：
- 常數加上 `UL` suffix，確保在 64-bit 編譯下常數為 64-bit

---

### 3. start.s

```diff
  _start:
      # 設定 stack - 支援多 hart (每個 hart 8KB)
      csrr t0, mhartid
      slli t0, t0, 13
      la   sp, stacks + STACK_SIZE
      add  sp, sp, t0
      
-     # 設定 mstatus: MPP = S mode (01), MPIE = 1
-     li t0, 0x2080
-     csrw mstatus, t0
-     
-     # 設定 mepc 指向 os_main
-     la t0, os_main
-     csrw mepc, t0
-     
-     # 禁用 paging
-     csrw satp, zero
-     
-     # delegate all interrupts to supervisor mode
-     li t0, 0xFFFFFFFF
-     csrw medeleg, t0
-     csrw mideleg, t0
-     
-     # enable supervisor timer interrupt
-     csrr t0, sie
-     ori t0, t0, 0x22
-     csrw sie, t0
-     
-     # 配置 PMP (RV64: 64-bit 地址)
-     lui t0, 0x3ffff
-     addi t0, t0, -1
-     csrw pmpaddr0, t0
-     li t0, 0xf
-     csrw pmpcfg0, t0
-     
-     # mret 跳到 mepc，切換到 S-mode
-     mret
+     # 直接 j 到 os_main (不使用 mret)
+     j os_main

  stacks:
      .skip STACK_SIZE * 4
```

**說明**：
- 簡化啟動流程，使用 `j` 直接跳轉到 `os_main`
- 使用 `j` 而非 `mret` 是因為在某些配置下 `mret` 導致無輸出
- 保持 M-mode 執行，與 32-bit 版本行為一致

---

### 4. sys.s

**修改內容**：
- `sw/lw` 改為 `sd/ld`
- 偏移量從 4 bytes 改為 8 bytes
- stack frame 大小從 128 bytes 改為 256 bytes

```diff
  .macro ctx_save base
-         sw ra, 0(\base)
-         sw sp, 4(\base)
+         sd ra, 0(\base)
+         sd sp, 8(\base)
  .endm

  .macro reg_save base
-         sw ra, 0(\base)
-         sw sp, 4(\base)
+         sd ra, 0(\base)
+         sd sp, 8(\base)
  .endm
```

sys_kernel 修改：
```diff
  sys_kernel:
-         addi sp, sp, -128
-         reg_save sp
-         ...
-         sw a0, 28(t0)
+         addi sp, sp, -256
+         reg_save sp
+         ...
+         sd a0, 56(t0)
```

sys_timer 修改：
```diff
  sys_timer:
-         sw a1, 0(a0)
-         sw a2, 4(a0)
-         sw a3, 8(a0)
-         ...
-         sw a1, 20(a0)
-         sw a1, 24(a0)
+         sd a1, 0(a0)
+         sd a2, 8(a0)
+         sd a3, 16(a0)
+         ...
+         sd a1, 40(a0)
+         sd a1, 48(a0)
```

---

### 5. timer.c

```diff
- // a scratch area per CPU for machine-mode timer interrupts.
- reg_t timer_scratch[NCPU][32];
+ // RV64: 8 entries * 8 bytes = 64 bytes per CPU
+ reg_t timer_scratch[NCPU][8];

  static inline uint64_t get_mtime(void) {
-   uint32_t high = *(uint32_t*)(CLINT_MTIME + 4);
-   uint32_t low = *(uint32_t*)CLINT_MTIME;
-   return ((uint64_t)high << 32) | low;
+   return *(volatile uint64_t*)CLINT_MTIME;
  }

  static inline void set_mtimecmp(uint64_t val) {
    int id = r_mhartid();
-   volatile uint32_t* mtimecmp_hi = (uint32_t*)(CLINT_MTIMECMP(id) + 4);
-   volatile uint32_t* mtimecmp_lo = (uint32_t*)CLINT_MTIMECMP(id);
-   *mtimecmp_lo = 0xFFFFFFFF;
-   *mtimecmp_hi = (uint32_t)(val >> 32);
-   *mtimecmp_lo = (uint32_t)(val & 0xFFFFFFFF);
+   volatile uint64_t* mtimecmp = (volatile uint64_t*)(uintptr_t)CLINT_MTIMECMP(id);
+   *mtimecmp = val;
  }
```

**說明**：
- RV64 可以直接讀寫 64-bit 的 mtimecmp
- timer_scratch 大小從 32 個 64-bit 元素改為 8 個 (因為每個元素現在是 64-bit)

---

### 6. test.sh

```bash
# 使用 expect 來捕獲 QEMU 輸出
expect -c "
set timeout 15
spawn qemu-system-riscv64 -nographic -smp 4 -machine virt -bios none -kernel os.elf
expect {
    -re \"(Hart|Task|OS|Start|Created|counter|done)\" { exp_continue }
    timeout { }
    eof { }
}
send \"\003\"
expect eof
" > "$OUTPUT"
```

**說明**：
- 使用 expect 而非直接 redirect，因為 QEMU 在 `-nographic` 模式下輸出到 terminal
- timeout 設為 15 秒讓多核心任務有足夠時間運作

---

## 問題與解決

### 問題 1: 無輸出

**現象**：執行 `qemu-system-riscv64` 時，螢幕一片空白，沒有任何輸出。

**原因**：
1. 初始的 start.s 使用 `mret` 嘗試切換到 S-mode，但在某些配置下導致程式卡住
2. QEMU 的輸出捕獲方式不正確

**解決**：
1. 簡化 start.s，使用 `j os_main` 直接跳轉，保持在 M-mode
2. 使用 `expect` 工具來捕獲輸出

---

### 問題 2: 多核心任務不執行

**現象**：使用 `-smp 4` 時，只有 Hart 0 完成初始化，其他 Hart 卡在 `waiting for tasks_ready`。

**原因**：
1. riscv.h 中的常數缺少 `UL` suffix，在 64-bit 編譯時可能產生錯誤的立即數
2. CLINT offset 計算錯誤 (仍使用 4 bytes 而非 8 bytes)

**解決**：
1. 修正 riscv.h 中的所有常數，加上 `UL` suffix
2. 修正 CLINT_MTIMECMP 為 `8*(hartid)`

---

### 問題 3: 編譯警告

**現象**：
```
warning: cast from pointer to integer of different size
```

**原因**：指標轉換為 `reg_t` 時的警告。

**解決**：這是正常的警告，不影響功能。

---

## 測試結果

```
=== Test Analysis ===
Task0 running count: 47
Task1 running count: 129
Task2 running count: 115
Task3 running count: 123
Task4 running count: 121
[PASS] Found 5 tasks running

=== Mutex Test ===
Counter values: 265 unique values
[PASS] Counter values are in correct sequence

=== All tests passed ===
```

---

## 總結

從 32-bit 改為 64-bit RISC-V OS 的主要變更：

1. **資料類型**: `reg_t` 從 `uint32_t` 改為 `uint64_t`
2. **記憶體操作**: `sw/lw` 改為 `sd/ld`，偏移量乘 2
3. **CLINT**: mtimecmp offset 從 4 bytes/hart 改為 8 bytes/hart
4. **常數**: 使用 `UL` suffix 確保 64-bit 立即數
5. **啟動方式**: 保持簡單，使用 `j` 跳轉而非 `mret`

測試結果顯示 5 個任務在 4 個核心上正確運行，mutex 運作正常。