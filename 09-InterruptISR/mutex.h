#ifndef __MUTEX_H__
#define __MUTEX_H__

#include "riscv.h"

typedef struct {
    int locked;
    int owner;
} mutex_t;

void mutex_init(mutex_t *m);
void mutex_lock(mutex_t *m);
void mutex_unlock(mutex_t *m);

#endif
