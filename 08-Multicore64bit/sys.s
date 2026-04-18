# This Code derived from xv6-riscv (64bit)
# -- https://github.com/mit-pdos/xv6-riscv/blob/riscv/kernel/swtch.S

# ============ MACRO ==================
.macro ctx_save base
        sd ra, 0(\base)
        sd sp, 8(\base)
        sd s0, 16(\base)
        sd s1, 24(\base)
        sd s2, 32(\base)
        sd s3, 40(\base)
        sd s4, 48(\base)
        sd s5, 56(\base)
        sd s6, 64(\base)
        sd s7, 72(\base)
        sd s8, 80(\base)
        sd s9, 88(\base)
        sd s10, 96(\base)
        sd s11, 104(\base)
.endm

.macro ctx_load base
        ld ra, 0(\base)
        ld sp, 8(\base)
        ld s0, 16(\base)
        ld s1, 24(\base)
        ld s2, 32(\base)
        ld s3, 40(\base)
        ld s4, 48(\base)
        ld s5, 56(\base)
        ld s6, 64(\base)
        ld s7, 72(\base)
        ld s8, 80(\base)
        ld s9, 88(\base)
        ld s10, 96(\base)
        ld s11, 104(\base)
.endm

.macro reg_save base
        sd ra, 0(\base)
        sd sp, 8(\base)
        sd gp, 16(\base)
        sd tp, 24(\base)
        sd t0, 32(\base)
        sd t1, 40(\base)
        sd t2, 48(\base)
        sd s0, 56(\base)
        sd s1, 64(\base)
        sd a0, 72(\base)
        sd a1, 80(\base)
        sd a2, 88(\base)
        sd a3, 96(\base)
        sd a4, 104(\base)
        sd a5, 112(\base)
        sd a6, 120(\base)
        sd a7, 128(\base)
        sd s2, 136(\base)
        sd s3, 144(\base)
        sd s4, 152(\base)
        sd s5, 160(\base)
        sd s6, 168(\base)
        sd s7, 176(\base)
        sd s8, 184(\base)
        sd s9, 192(\base)
        sd s10, 200(\base)
        sd s11, 208(\base)
        sd t3, 216(\base)
        sd t4, 224(\base)
        sd t5, 232(\base)
        sd t6, 240(\base)
.endm

.macro reg_load base
        ld ra, 0(\base)
        ld sp, 8(\base)
        ld gp, 16(\base)
        ld t0, 32(\base)
        ld t1, 40(\base)
        ld t2, 48(\base)
        ld s0, 56(\base)
        ld s1, 64(\base)
        ld a0, 72(\base)
        ld a1, 80(\base)
        ld a2, 88(\base)
        ld a3, 96(\base)
        ld a4, 104(\base)
        ld a5, 112(\base)
        ld a6, 120(\base)
        ld a7, 128(\base)
        ld s2, 136(\base)
        ld s3, 144(\base)
        ld s4, 152(\base)
        ld s5, 160(\base)
        ld s6, 168(\base)
        ld s7, 176(\base)
        ld s8, 184(\base)
        ld s9, 192(\base)
        ld s10, 200(\base)
        ld s11, 208(\base)
        ld t3, 216(\base)
        ld t4, 224(\base)
        ld t5, 232(\base)
        ld t6, 240(\base)
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
        # Save all registers to task's stack (256 bytes for 32 regs * 8 bytes)
        addi sp, sp, -256
        reg_save sp
        
        # Save original sp (before subtracting 256) to mscratch
        csrrw t0, mscratch, t0
        addi a0, sp, 256
        sd a0, 56(t0)
        csrrw t0, mscratch, t0
        
        call timer_handler
        
        # This should never be reached since timer_handler calls task_os()
        # But if it is, restore and return to interrupted task
        reg_load sp
        addi sp, sp, 256

        # restore mepc from mscratch
        csrrw a0, mscratch, a0
        sd a1, 0(a0)
        ld a1, 40(a0)
        csrw mepc, a1
        ld a1, 0(a0)
        csrrw a0, mscratch, a0
        
        ret

# Timer interrupt handler
# scratch[0-2]: a0, a1, a2 (saved)
# scratch[3]: mtimecmp address (CLINT_MTIMECMP)
# scratch[4]: interval
# scratch[5]: mepc
# scratch[6]: mcause
.globl sys_timer
.align 4
sys_timer:
        # Save a0, a1, a2 to scratch area (offset 0, 8, 16)
        csrrw a0, mscratch, a0
        sd a1, 0(a0)
        sd a2, 8(a0)
        sd a3, 16(a0)
        
        # Save mepc and mcause (offset 40, 48)
        csrr a1, mepc
        sd a1, 40(a0)
        csrr a1, mcause
        sd a1, 48(a0)
        
        # Set mepc to sys_kernel
        la a1, sys_kernel
        csrw mepc, a1
        
        # Schedule next timer interrupt
        # scratch[3] = mtimecmp address, scratch[4] = interval
        ld a1, 24(a0)   # mtimecmp address
        ld a2, 32(a0)   # interval
        ld a3, 0(a1)    # current mtimecmp
        add a3, a3, a2  # add interval
        sd a3, 0(a1)   # write back
        
        # Restore a0, a1, a2
        ld a3, 16(a0)
        ld a2, 8(a0)
        ld a1, 0(a0)
        csrrw a0, mscratch, a0
        
        mret