#include "os.h"
#include "mutex.h"

extern volatile int tasks_ready;
extern int taskTop;

mutex_t m;
int shared_counter = 0;

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
	while (1) {
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
