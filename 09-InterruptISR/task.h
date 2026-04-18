#ifndef __TASK_H__
#define __TASK_H__

#include "riscv.h"
#include "sys.h"

#define MAX_TASK 10
#define STACK_SIZE 1024

extern int taskTop;

extern int  task_create(void (*task)(void));
extern void task_go(int i);
extern void task_os();
extern void task_yield();
extern void init_scheduler(int id);
extern int scheduler_next();

#endif
