#include "os.h"
#include "mutex.h"
#include "isr.h"

extern volatile int tasks_ready;
extern int taskTop;

mutex_t m;
int shared_counter = 0;

static volatile int isr_call_count = 0;

void my_timer_isr(void) {
    isr_call_count++;
}

void user_task0(void)
{
    lib_printf("Task0 [hart %d]: Created!\n", r_mhartid());
    while (1) {
        mutex_lock(&m);
        lib_printf("Task0 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task0 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        task_yield();
        lib_delay(200);
    }
}

void user_task1(void)
{
    lib_printf("Task1 [hart %d]: Created!\n", r_mhartid());
    while (1) {
        mutex_lock(&m);
        lib_printf("Task1 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task1 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        task_yield();
        lib_delay(200);
    }
}

void user_task2(void)
{
    lib_printf("Task2 [hart %d]: Created!\n", r_mhartid());
    while (1) {
        mutex_lock(&m);
        lib_printf("Task2 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task2 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        task_yield();
        lib_delay(200);
    }
}

void user_task3(void)
{
    lib_printf("Task3 [hart %d]: Created!\n", r_mhartid());
    while (1) {
        mutex_lock(&m);
        lib_printf("Task3 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task3 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        task_yield();
        lib_delay(200);
    }
}

void user_task4(void)
{
    lib_printf("Task4 [hart %d]: Created!\n", r_mhartid());
    
    lib_printf("Task4: registering ISR for IRQ 5...\n");
    isr_register(5, my_timer_isr);
    lib_printf("Task4: ISR registered, call_count=%d\n", isr_call_count);
    
    int last_count = 0;
    while (1) {
        if (isr_call_count != last_count) {
            lib_printf("Task4 [hart %d]: ISR called! count=%d\n", r_mhartid(), isr_call_count);
            last_count = isr_call_count;
        }
        
        mutex_lock(&m);
        lib_printf("Task4 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        shared_counter++;
        lib_printf("Task4 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
        
        task_yield();
        lib_delay(200);
    }
}

void user_init() {
    mutex_init(&m);
    task_create(&user_task0);
    task_create(&user_task1);
    task_create(&user_task2);
    task_create(&user_task3);
    task_create(&user_task4);
    lib_printf("user_init: created %d tasks\n", taskTop);
    tasks_ready = 1;
}
