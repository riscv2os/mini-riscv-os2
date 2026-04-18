#ifndef __ISR_H__
#define __ISR_H__

#include "riscv.h"

#define MAX_ISR 16

typedef void (*isr_handler_t)(void);

typedef struct {
    int irq;
    isr_handler_t handler;
} isr_entry_t;

void isr_init();
int  isr_register(int irq, isr_handler_t handler);
void isr_dispatch(int irq);

#endif