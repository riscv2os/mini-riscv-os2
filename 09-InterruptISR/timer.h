#ifndef __TIMER_H__
#define __TIMER_H__

#include "riscv.h"
#include "sys.h"
#include "lib.h"
#include "task.h"
#include "isr.h"

extern void timer_handler();
extern void timer_handler_isr();
extern void timer_init();

#define TIMER_IRQ 7

#endif