#include "os.h"

volatile int tasks_ready = 0;
volatile int harts_ready = 0;

void os_kernel() {
    task_os();
}

void os_start() {
    int id = r_mhartid();
    
    // 直接寫入 UART 測試
    volatile char *uart = (volatile char*)0x10000000;
    uart[0] = 'H';
    uart[0] = 'i';
    uart[0] = '\r';
    uart[0] = '\n';
    
    // 無窮迴圈
    while(1) {}
}

int os_main(void)
{
    os_start();
    return 0;
}