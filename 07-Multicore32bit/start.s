.equ STACK_SIZE, 8192

.global _start

_start:
    # set M Previous Privilege mode to Supervisor, for mret.
    csrr t0, mstatus
    # set MPP to Supervisor mode
    li t0, -1
    andi t0, t0, 0xfffffff7    # clear MPP bits
    ori  t0, t0, 0x200        # set MPP to Supervisor mode (01)
    csrw mstatus, t0

    # set M Exception Program Counter to os_main, for mret.
    la t0, os_main
    csrw mepc, t0

    # disable paging for now.
    csrw satp, zero

    # delegate all interrupts and exceptions to supervisor mode.
    li t0, 0xFFFFFFFF
    csrw medeleg, t0
    csrw mideleg, t0

    # enable supervisor-mode timer and external interrupts.
    csrr t0, sie
    ori t0, t0, 0x22          # SEIE | STIE
    csrw sie, t0

    # configure PMP to give supervisor mode access to all memory.
    li t0, 0x3ffffffffffffful
    csrw pmpaddr0, t0
    li t0, 0xf
    csrw pmpcfg0, t0

    # Get hartid - all harts will continue to os_main
    csrr t0, mhartid

    # setup stacks per hart - each hart gets its own stack
    # Stack size is 8KB (8192), shift left 13 bits (8192 = 2^13)
    csrr t0, mhartid
    slli t0, t0, 13
    la   sp, stacks + STACK_SIZE
    add  sp, sp, t0

    # All harts jump to os_main (no wfi/hang)
    # Each hart will run independently through os_main
    mret

stacks:
    .skip STACK_SIZE * 4
