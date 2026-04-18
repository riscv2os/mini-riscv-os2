#include "os.h"

int task0_count = 0;
int task1_count = 0;

void user_task0(void)
{
	lib_puts("Task0: Created!\n");
	while (1) {
		lib_printf("Task0: Running..., count=%d\n", ++task0_count);
		lib_delay(1000);
	}
}

void user_task1(void)
{
	lib_puts("Task1: Created!\n");
	while (1) {
		lib_printf("Task1: Running..., count=%d\n", ++task1_count);
		lib_delay(1000);
	}
}

void user_init() {
	task_create(&user_task0);
	task_create(&user_task1);
}
