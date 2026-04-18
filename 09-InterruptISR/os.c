#include "os.h"

volatile int tasks_ready = 0;
volatile int harts_ready = 0;

void os_kernel() {
    task_os();
}

void os_start() {
    int id = r_mhartid();
    
    lib_printf("Hart %d: in os_start\n", id);
    
    if (id == 0) {
        lib_printf("Hart %d: OS start, initializing ISR\n", id);
        isr_init();
        lib_printf("Hart %d: OS start, initializing tasks\n", id);
        user_init();
        __sync_synchronize();
        tasks_ready = 1;
        lib_printf("Hart %d: tasks_ready = 1\n", id);
    }
    
    lib_printf("Hart %d: waiting for tasks_ready\n", id);
    while (!tasks_ready) {}
    __sync_synchronize();
    
    lib_printf("Hart %d: init scheduler\n", id);
    init_scheduler(id);
    timer_init();
    __sync_synchronize();
    harts_ready++;
    
    lib_printf("Hart %d: done, harts_ready=%d\n", id, harts_ready);
}

int os_main(void)
{
    os_start();
    
    while (1) {
        int my_task = scheduler_next();
        task_go(my_task);
    }
    return 0;
}