#include "task.h"
#include "lib.h"
#include "mutex.h"

uint8_t task_stack[MAX_TASK][STACK_SIZE];
struct context ctx_os[NCPU];
struct context ctx_tasks[MAX_TASK];
struct context *ctx_now[NCPU];
int current_task[NCPU] = {0};
int taskTop=0;

static volatile int task_counter = 0;
static volatile int task_running[MAX_TASK];
static int initialized = 0;
static mutex_t scheduler_lock;

void init_scheduler(int id) {
    current_task[id] = -1;
    if (!initialized) {
        if (id == 0) {
            task_counter = 0;
            for (int i = 0; i < MAX_TASK; i++) {
                task_running[i] = 0;
            }
            mutex_init(&scheduler_lock);
            initialized = 1;
        }
    }
    while (!initialized) {}
}

int scheduler_next() {
    int id = r_mhartid();
    
    mutex_lock(&scheduler_lock);
    
    // Release current task and move to next
    if (current_task[id] >= 0 && current_task[id] < taskTop) {
        task_running[current_task[id]] = 0;
    }
    
    // Simple round-robin: start from (current task + 1) % taskTop
    int start = (current_task[id] + 1) % taskTop;
    
    // First pass: try tasks after current
    for (int i = 0; i < taskTop; i++) {
        int idx = (start + i) % taskTop;
        if (task_running[idx] == 0) {
            task_running[idx] = 1;
            mutex_unlock(&scheduler_lock);
            return idx;
        }
    }
    
    // Second pass: all taken, forcibly steal from any task (round-robin)
    int steal_start = (current_task[id] + 1) % taskTop;
    for (int i = 0; i < taskTop; i++) {
        int idx = (steal_start + i) % taskTop;
        task_running[idx] = 0;
    }
    
    // Third pass: now all are free, pick from start
    for (int i = 0; i < taskTop; i++) {
        int idx = (start + i) % taskTop;
        task_running[idx] = 1;
        mutex_unlock(&scheduler_lock);
        return idx;
    }
    
    mutex_unlock(&scheduler_lock);
    return 0;
}

int task_create(void (*task)(void))
{
	int i = taskTop++;
	ctx_tasks[i].ra = (reg_t) task;
	ctx_tasks[i].sp = (reg_t) &task_stack[i][STACK_SIZE-1];
	return i;
}

void task_go(int i) {
	int id = r_mhartid();
	ctx_now[id] = &ctx_tasks[i];
	current_task[id] = i;
	sys_switch(&ctx_os[id], &ctx_tasks[i]);
}

void task_os() {
    int id = r_mhartid();
    struct context *ctx = ctx_now[id];
    ctx_now[id] = &ctx_os[id];
    mutex_lock(&scheduler_lock);
    task_running[current_task[id]] = 0;
    mutex_unlock(&scheduler_lock);
    sys_switch(ctx, &ctx_os[id]);
}

void task_yield() {
    task_os();
}
