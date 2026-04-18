# 修復報告 2

## 問題描述

修復後的版本雖然可以正常切換任務，但存在以下問題：

1. **定時器中斷只觸發一次**：Task0 運行結束後，Task1 開始運行，但第二次定時器中斷永遠不會觸發
2. **任務計數錯誤**：每次切換到任務時，計數器都會重置（Task1 第二次運行時 count 從 1 開始）

## 問題根因

### Bug 1: mtime 是 64 位寄存器

**問題**：在 RV32 架構上，`mtime` 和 `mtimecmp` 是 64 位寄存器，但我們錯誤地使用 32 位存取。

```c
// 錯誤的寫法（32位）
*(reg_t*)CLINT_MTIMECMP(id) = *(reg_t*)CLINT_MTIME + interval;
```

根據 RISC-V 規格書：
> The mtime register has a 64-bit precision on all RV32 and RV64 systems.

**解決方案**：正確讀寫 64 位值，先寫入 0xFFFFFFFF 到低位防止偽中斷。

### Bug 2: MIE（中斷使能）沒有恢復

**問題**：當使用 `ret` 指令返回時，不會恢復 `mstatus.MIE` 位。

RISC-V 規定：
- 進入中斷時：`mstatus.MIE` → `mstatus.MPIE`，然後 `mstatus.MIE = 0`
- 離開中斷時（`mret`）：恢復 `mstatus.MIE = mstatus.MPIE`

原始版本使用兩層 `mret`：
1. `sys_timer` → `mret` → `sys_kernel`（此時 MIE 被恢復）
2. `sys_kernel` 返回後 → `mret` → 恢復 MIE 並返回被中斷任務

我們的實作只使用 `ret`，導致 MIE 永遠為 0，定時器中斷無法再次觸發。

### Bug 3: 任務棧沒有正確保存

**問題**：當定時器中斷發生時，`sys_kernel` 保存所有寄存器到任務棧，但 `timer_handler` 調用 `task_os()` 切換走後，這些寄存器從未被恢復。

任務第二次運行時，是從 `ctx_tasks` 加载 ra/sp，相當於一個新的任務實例，所以本地變量（count）會重置。

## 修復方式

### 1. 正確處理 64 位 mtime/mtimecmp

```c
// 讀取 64 位 mtime
static inline uint64_t get_mtime(void) {
  uint32_t high = *(uint32_t*)(CLINT_MTIME + 4);
  uint32_t low = *(uint32_t*)CLINT_MTIME;
  return ((uint64_t)high << 32) | low;
}

// 寫入 64 位 mtimecmp（防止偽中斷）
static inline void set_mtimecmp(uint64_t val) {
  volatile uint32_t* mtimecmp_hi = (uint32_t*)(CLINT_MTIMECMP(0) + 4);
  volatile uint32_t* mtimecmp_lo = (uint32_t*)CLINT_MTIMECMP(0);
  *mtimecmp_lo = 0xFFFFFFFF;  // 先寫低位為 -1
  *mtimecmp_hi = (uint32_t)(val >> 32);
  *mtimecmp_lo = (uint32_t)(val & 0xFFFFFFFF);
}
```

### 2. 使用全局變量保存任務計數

由於每次任務切換都是一個新的任務實例（從 ctx_tasks 恢覆），棧上的本地變數會丟失。改用全局變量：

```c
int task0_count = 0;
int task1_count = 0;

void user_task0(void) {
    while (1) {
        lib_printf("Task0: Running..., count=%d\n", ++task0_count);
        lib_delay(1000);
    }
}
```

### 3. 恢復正確的流程

定時器中斷發生時的流程：
1. `sys_timer`：保存少量寄存器到 scratch，設置 mepc = sys_kernel，mret 跳轉
2. `sys_kernel`：保存所有寄存器到任務棧，調用 timer_handler
3. `timer_handler`：調用 os_kernel() → task_os()
4. `task_os()`：保存當前任務的 ra/sp 到 ctx_tasks，切換到 OS
5. OS 調度下一個任務

這個流程與原始版本一致，確保每次任務切換都是通過 ctx_tasks 進行的。

## 測試結果

```
=== Output ===
OS start
OS: Activate next task
Task0: Created!
Task0: Running..., count=1
...
Task0: Running..., count=32
timer_handler: 1
Task1: Created!
Task1: Running..., count=1
...
Task1: Running..., count=31
timer_handler: 2
OS: Back to OS
OS: Activate next task
Task0: Running..., count=33    <-- 正確！從中斷點繼續
Task0: Running..., count=34
...
Task0: Running..., count=45
timer_handler: 3
OS: Back to OS
OS: Activate next task
Task1: Running..., count=32    <-- 正確！從中斷點繼續
...

=== Test Analysis ===
[PASS] Both tasks were created
Task0 running count: 94
Task1 running count: 64
[PASS] Tasks ran multiple times (not restarting from beginning)
=== All tests passed ===
```

## 修改檔案清單

| 檔案 | 修改內容 |
|------|----------|
| `timer.c` | 新增 64 位 mtime 讀寫函數，修正定時器初始化 |
| `user.c` | 使用全局變量保存任務計數 |
| `os.c` | 新增 os_kernel() 函數 |

## 關鍵學習

1. **RISC-V 64 位寄存器在 32 位架構上的處理**：需要分高低位讀寫
2. **mret 指令會自動恢復 MIE**：這是定時器中斷能夠重複觸發的關鍵
3. **搶佔式多任務的本質**：每次中斷都會保存完整任務狀態，切換到另一個任務；任務恢復時從 ctx 繼續
