#include "isr.h"

static isr_entry_t isr_table[MAX_ISR];
static int isr_count = 0;

void isr_init() {
    for (int i = 0; i < MAX_ISR; i++) {
        isr_table[i].irq = -1;
        isr_table[i].handler = 0;
    }
    isr_count = 0;
}

int isr_register(int irq, isr_handler_t handler) {
    if (irq < 0 || irq >= MAX_ISR) {
        return -1;
    }
    
    isr_table[irq].irq = irq;
    isr_table[irq].handler = handler;
    return 0;
}

void isr_dispatch(int irq) {
    if (irq >= 0 && irq < MAX_ISR) {
        if (isr_table[irq].handler != 0) {
            isr_table[irq].handler();
        }
    }
}