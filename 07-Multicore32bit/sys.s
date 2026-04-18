# This Code derived from xv6-riscv (64bit)
# -- https://github.com/mit-pdos/xv6-riscv/blob/riscv/kernel/swtch.S

# ============ MACRO ==================
.macro ctx_save base
        sw ra, 0(\base)
        sw sp, 4(\base)
        sw s0, 8(\base)
        sw s1, 12(\base)
        sw s2, 16(\base)
        sw s3, 20(\base)
        sw s4, 24(\base)
        sw s5, 28(\base)
        sw s6, 32(\base)
        sw s7, 36(\base)
        sw s8, 40(\base)
        sw s9, 44(\base)
        sw s10, 48(\base)
        sw s11, 52(\base)
.endm

.macro ctx_load base
        lw ra, 0(\base)
        lw sp, 4(\base)
        lw s0, 8(\base)
        lw s1, 12(\base)
        lw s2, 16(\base)
        lw s3, 20(\base)
        lw s4, 24(\base)
        lw s5, 28(\base)
        lw s6, 32(\base)
        lw s7, 36(\base)
        lw s8, 40(\base)
        lw s9, 44(\base)
        lw s10, 48(\base)
        lw s11, 52(\base)
.endm

.macro reg_save base
        sw ra, 0(\base)
        sw sp, 4(\base)
        sw gp, 8(\base)
        sw tp, 12(\base)
        sw t0, 16(\base)
        sw t1, 20(\base)
        sw t2, 24(\base)
        sw s0, 28(\base)
        sw s1, 32(\base)
        sw a0, 36(\base)
        sw a1, 40(\base)
        sw a2, 44(\base)
        sw a3, 48(\base)
        sw a4, 52(\base)
        sw a5, 56(\base)
        sw a6, 60(\base)
        sw a7, 64(\base)
        sw s2, 68(\base)
        sw s3, 72(\base)
        sw s4, 76(\base)
        sw s5, 80(\base)
        sw s6, 84(\base)
        sw s7, 88(\base)
        sw s8, 92(\base)
        sw s9, 96(\base)
        sw s10, 100(\base)
        sw s11, 104(\base)
        sw t3, 108(\base)
        sw t4, 112(\base)
        sw t5, 116(\base)
        sw t6, 120(\base)
.endm

.macro reg_load base
        lw ra, 0(\base)
        lw sp, 4(\base)
        lw gp, 8(\base)
        lw t0, 16(\base)
        lw t1, 20(\base)
        lw t2, 24(\base)
        lw s0, 28(\base)
        lw s1, 32(\base)
        lw a0, 36(\base)
        lw a1, 40(\base)
        lw a2, 44(\base)
        lw a3, 48(\base)
        lw a4, 52(\base)
        lw a5, 56(\base)
        lw a6, 60(\base)
        lw a7, 64(\base)
        lw s2, 68(\base)
        lw s3, 72(\base)
        lw s4, 76(\base)
        lw s5, 80(\base)
        lw s6, 84(\base)
        lw s7, 88(\base)
        lw s8, 92(\base)
        lw s9, 96(\base)
        lw s10, 100(\base)
        lw s11, 104(\base)
        lw t3, 108(\base)
        lw t4, 112(\base)
        lw t5, 116(\base)
        lw t6, 120(\base)
.endm
# ============ Macro END   ==================

# Context switch
.globl sys_switch
.align 4
sys_switch:
        ctx_save a0  # a0 => struct context *old
        ctx_load a1  # a1 => struct context *new
        ret

# sys_kernel is called from sys_timer via mret
# It saves registers, calls timer_handler which switches to OS
.globl sys_kernel
.align 4
sys_kernel:
        # Save all registers to task's stack
        addi sp, sp, -128
        reg_save sp
        
        # Save original sp (before subtracting 128) to mscratch
        csrrw t0, mscratch, t0
        addi a0, sp, 128
        sw a0, 28(t0)
        csrrw t0, mscratch, t0
        
        call timer_handler
        
        # This should never be reached since timer_handler calls task_os()
        # But if it is, restore and return to interrupted task
        reg_load sp
        addi sp, sp, 128

        # restore mepc from mscratch
        csrrw a0, mscratch, a0
        sw a1, 0(a0)
        lw a1, 20(a0)
        csrw mepc, a1
        lw a1, 0(a0)
        csrrw a0, mscratch, a0
        
        ret

# Timer interrupt handler
.globl sys_timer
.align 4
sys_timer:
        # Save a0, a1, a2 to scratch area
        csrrw a0, mscratch, a0
        sw a1, 0(a0)
        sw a2, 4(a0)
        sw a3, 8(a0)
        
        # Save mepc and mcause
        csrr a1, mepc
        sw a1, 20(a0)
        csrr a1, mcause
        sw a1, 24(a0)
        
        # Set mepc to sys_kernel
        la a1, sys_kernel
        csrw mepc, a1
        
        # Schedule next timer interrupt
        lw a1, 12(a0)
        lw a2, 16(a0)
        lw a3, 0(a1)
        add a3, a3, a2
        sw a3, 0(a1)
        
        # Restore a0, a1, a2
        lw a3, 8(a0)
        lw a2, 4(a0)
        lw a1, 0(a0)
        csrrw a0, mscratch, a0
        
        mret
