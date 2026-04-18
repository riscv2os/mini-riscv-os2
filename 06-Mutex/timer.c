#include "timer.h"
#include <stdint.h>

extern void os_kernel();

// a scratch area per CPU for machine-mode timer interrupts.
reg_t timer_scratch[NCPU][32];

// Use 64-bit for mtime/mtimecmp - they are 64-bit registers even on RV32
static inline uint64_t get_mtime(void) {
  // Read both halves - must read high first, then low for atomic-like read
  // to avoid getting inconsistent values during overflow
  uint32_t high = *(uint32_t*)(CLINT_MTIME + 4);
  uint32_t low = *(uint32_t*)CLINT_MTIME;
  return ((uint64_t)high << 32) | low;
}

static inline void set_mtimecmp(uint64_t val) {
  // RV32: Must write high bits first, then low bits with 0xFFFFFFFF to prevent spurious interrupt
  // See RISC-V spec Section 3.2.1
  volatile uint32_t* mtimecmp_hi = (uint32_t*)(CLINT_MTIMECMP(0) + 4);
  volatile uint32_t* mtimecmp_lo = (uint32_t*)CLINT_MTIMECMP(0);
  *mtimecmp_lo = 0xFFFFFFFF;  // Prevent interrupt between writes
  *mtimecmp_hi = (uint32_t)(val >> 32);
  *mtimecmp_lo = (uint32_t)(val & 0xFFFFFFFF);
}

void timer_init()
{
  int id = r_mhartid();

  uint64_t interval = 20000000ULL;
  uint64_t now = get_mtime();
  set_mtimecmp(now + interval);

  reg_t *scratch = &timer_scratch[id][0];
  scratch[3] = CLINT_MTIMECMP(id);
  scratch[4] = interval;
  w_mscratch((reg_t)scratch);

  w_mtvec((reg_t)sys_timer);
  w_mstatus(r_mstatus() | MSTATUS_MIE);
  w_mie(r_mie() | MIE_MTIE);
}

static int timer_count = 0;

extern void task_os();

void timer_handler() {
  lib_printf("timer_handler: %d\n", ++timer_count);
  task_os();
}
