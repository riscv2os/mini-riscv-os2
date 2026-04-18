#include "os.h"
#include "mutex.h"

mutex_t m;
int shared_counter = 0;

void user_task0(void)
{
	lib_puts("Task0: Created!\n");
	while (1) {
		mutex_lock(&m);
		lib_printf("Task0: counter before = %d\n", shared_counter);
		shared_counter++;
		lib_printf("Task0: counter after  = %d\n", shared_counter);
		mutex_unlock(&m);
		lib_delay(1000);
	}
}

void user_task1(void)
{
	lib_puts("Task1: Created!\n");
	while (1) {
		mutex_lock(&m);
		lib_printf("Task1: counter before = %d\n", shared_counter);
		shared_counter++;
		lib_printf("Task1: counter after  = %d\n", shared_counter);
		mutex_unlock(&m);
		lib_delay(1000);
	}
}

void user_init() {
	mutex_init(&m);
	task_create(&user_task0);
	task_create(&user_task1);
}
