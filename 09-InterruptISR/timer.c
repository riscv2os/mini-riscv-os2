#include "timer.h"
#include <stdint.h>

extern void os_kernel();

// a scratch area per CPU for machine-mode timer interrupts.
// RV64: 8 entries * 8 bytes = 64 bytes per CPU
reg_t timer_scratch[NCPU][8];

static inline uint64_t get_mtime(void) {
  return *(volatile uint64_t*)CLINT_MTIME;
}

static inline void set_mtimecmp(uint64_t val) {
  int id = r_mhartid();
  volatile uint64_t* mtimecmp = (volatile uint64_t*)(uintptr_t)CLINT_MTIMECMP(id);
  *mtimecmp = val;
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

  isr_register(TIMER_IRQ, timer_handler_isr);
}

static int timer_count = 0;
static int timer_count_per_hart[NCPU] = {0};

extern void task_os();

void timer_handler() {
  int id = r_mhartid();
  timer_count_per_hart[id]++;
  task_os();
}

void timer_handler_isr() {
  int id = r_mhartid();
  timer_count_per_hart[id]++;
  timer_count++;
  
  uint64_t now = get_mtime();
  uint64_t interval = timer_scratch[id][4];
  set_mtimecmp(now + interval);
  
  task_os();
}