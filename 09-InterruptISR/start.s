.equ STACK_SIZE, 8192

.global _start

_start:
    # 設定 stack - 支援多 hart (每個 hart 8KB)
    csrr t0, mhartid
    slli t0, t0, 13
    la   sp, stacks + STACK_SIZE
    add  sp, sp, t0
    
    # 直接 j 到 os_main (不使用 mret)
    # 保持在 M-mode 執行
    j os_main

stacks:
    .skip STACK_SIZE * 4