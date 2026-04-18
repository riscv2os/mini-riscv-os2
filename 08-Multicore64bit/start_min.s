.equ STACK_SIZE, 8192

.global _start

_start:
    # 設定 stack
    la sp, stacks + STACK_SIZE
    
    # 直接跳到 os_main
    j os_main

stacks:
    .skip STACK_SIZE