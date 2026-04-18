#include "timer.h"
#include <stdint.h>

extern void os_kernel();

// a scratch area per CPU for machine-mode timer interrupts.
reg_t timer_scratch[NCPU][32];

static inline uint64_t get_mtime(void) {
  uint32_t high = *(uint32_t*)(CLINT_MTIME + 4);
  uint32_t low = *(uint32_t*)CLINT_MTIME;
  return ((uint64_t)high << 32) | low;
}

static inline void set_mtimecmp(uint64_t val) {
  int id = r_mhartid();
  volatile uint32_t* mtimecmp_hi = (uint32_t*)(CLINT_MTIMECMP(id) + 4);
  volatile uint32_t* mtimecmp_lo = (uint32_t*)CLINT_MTIMECMP(id);
  *mtimecmp_lo = 0xFFFFFFFF;
  *mtimecmp_hi = (uint32_t)(val >> 32);
  *mtimecmp_lo = (uint32_t)(val & 0xFFFFFFFF);
}

void timer_init()
{
  int id = r_mhartid();

  uint64_t interval = 100000ULL;
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
static int timer_count_per_hart[NCPU] = {0};

extern void task_os();

void timer_handler() {
  int id = r_mhartid();
  timer_count_per_hart[id]++;
  task_os();
}
