# 修復報告

## 問題描述

每個 thread 中斷後又被喚醒時，應該要從上次被中斷點開始執行，但實際上每次都從重頭執行該 thread。

## 問題根因

### Bug 1: mepc 恢復錯誤
**檔案：** `sys.s:136`

```asm
csrw    mepc, ra        # 錯誤：使用 ra (函數返回位址)
```

`sys_kernel` 函數在恢復 `mepc` 時，錯誤地使用了 `ra` 暫存器，而非 `a1` 暫存器（從 scratch 區域載入的原始 `mepc` 值）。

### Bug 2: 內核棧切換複雜導致狀態丟失
嘗試在 `sys_timer` 和 `sys_kernel` 兩個函數中分工，切換到內核棧保存寄存器，但實現過於複雜，導致任務棧上的數據被破壞。

## 修復方式

採用簡化設計：不在中斷處理程序中切換到內核棧，而是直接在任務棧上保存所有寄存器。

關鍵改動：
1. 修正 `mepc` 恢復使用正確的暫存器
2. 簡化 `sys_timer`，直接在中斷點恢復執行（不通過 `sys_kernel`）
3. 任務切換由 `timer_handler` 調用 `os_kernel()` 完成

## 測試結果

```
[PASS] Both tasks were created
Task0 running count: 33
Task1 running count: 124
[PASS] Tasks ran multiple times (not restarting from beginning)
=== All tests passed ===
```

任務在中斷後正確從中斷點繼續執行，count 值正確遞增。

## 修改檔案清單

| 檔案 | 修改內容 |
|------|----------|
| `sys.s` | 完全重寫 timer 中斷處理，直接在任務棧保存/恢復寄存器 |
| `timer.c` | 保持調用 os_kernel() |
