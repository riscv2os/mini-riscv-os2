# 除錯報告：Preemptive OS 無法從中斷點恢復執行

## 問題描述

每個 thread 中斷後又被喚醒時，應該要從上次被中斷點開始執行，但實際上每次都從重頭執行該 thread。

## 問題分析

### 程式運作流程

1. `task_create()` 建立任務時，將任務函數指標存入 `ctx_tasks[i].ra`，作為上下文切換後的返回位址
2. 定時器中斷發生時，`sys_timer` 儲存當前 `mepc`（被中斷的程式位置）到 scratch 區域
3. 中斷處理完成後，透過 `mret` 返回並跳轉到 `mepc` 指定的位置

### Bug 位置

**檔案：** `sys.s` 第 136 行

```asm
sys_kernel:
        ...
        # restore mepc from scratch
        csrrw a0, mscratch, a0 # exchange(mscratch,a0)
        sw      a1, 0(a0)
        lw      a1, 20(a0)     # a1 = 保存的 mepc 值
        csrw    mepc, ra        # BUG: 應該用 a1，不是 ra
        lw      a1, 0(a0)
        csrrw a0, mscratch, a0 # exchange(mscratch,a0)
        ret
```

### 原因說明

在第 136 行，`csrw mepc, ra` 將 `mepc` 設定為 `ra` 暫存器的值，而不是 `a1` 暫存器中保存的原始 `mepc` 值。

- `a1` 暫存器：從 scratch 區域載入的原始 `mepc` 值（中斷發生時的程式位置）
- `ra` 暫存器：`sys_kernel` 函數的返回位址

因此，當 `mret` 執行時，處理器會跳轉到錯誤的位置（`sys_kernel` 的返回位址），而非任務被中斷時的位址。

### 修復方式

將第 136 行修改為：

```asm
        csrw    mepc, a1        # 從 a1 恢復 mepc
```

## 結論

此 bug 導致任務恢復時無法回到被中斷的位置，而是跳轉到錯誤的位址，造成任務每次都「從重頭執行」的現象。
