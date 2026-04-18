# Mutex 多核心修改計劃

## 1. 現況分析

目前系統：
- QEMU 以 `-smp 4` 啟動（4 核心），但只有 hart 0 執行任務
- 其他 harts 在 `start.s` 的 `park:` 處執行 `wfi` 空迴圈
- 所有任務都在 hart 0 上執行，無法測試多核心並髑下定mutex

## 2. 修改目標

讓多個 hart 同時執行不同的任務，真正測試 mutex 在多核心並髑下的正確性。

## 3. 架構修改

### 3.1 目前架構
```
hart 0: [Task0] -> [Task1] -> [Task0] -> ... (單核心排程)
hart 1: [park]
hart 2: [park]
hart 3: [park]
```

### 3.2 目標架構
```
hart 0: [Task0] <-> [OS scheduler]
hart 1: [Task1] <-> [OS scheduler]
hart 2: [Task2] <-> [OS scheduler]
hart 3: [park]
```

## 4. 實作要點

### 4.1 task.c 修改
```c
struct context ctx_os[NCPU];      // 每個 hart 有獨立的 OS 上下文
struct context *ctx_now[NCPU];     // 每個 hart 有當前任務指標
int current_task[NCPU];            // 每個 hart 的當前任務 ID

// 取得當前 hart ID
int hart_id = r_mhartid();

// 讓指定任務在當前 hart 執行
void task_go(int i) {
    int hid = r_mhartid();
    ctx_now[hid] = &ctx_tasks[i];
    sys_switch(&ctx_os[hid], &ctx_tasks[i]);
}

// 切換回 OS（當前 hart）
void task_os() {
    int hid = r_mhartid();
    struct context *ctx = ctx_now[hid];
    ctx_now[hid] = &ctx_os[hid];
    sys_switch(ctx, &ctx_os[hid]);
}
```

### 4.2 timer.c 修改
```c
// 每個 hart 有獨立的 timer scratch area
reg_t timer_scratch[NCPU][32];

void timer_init() {
    int id = r_mhartid();  // 取得當前 hart ID
    // 設定該 hart 的 timer scratch 和中斷
}
```

### 4.3 os.c 修改
每個 hart 都需要進入 OS 主迴圈：

```c
int os_main(void) {
    int hid = r_mhartid();
    
    if (hid == 0) {
        // hart 0: 初始化任務
        os_start();
    }
    
    // 每個 hart 都進入排程迴圈
    int current_task = 0;
    while (1) {
        lib_puts("OS: Activate next task\n");
        task_go(current_task);
        lib_puts("OS: Back to OS\n");
        current_task = (current_task + 1) % taskTop;
    }
}
```

### 4.4 start.s 修改
讓所有 harts 都進入 os_main（不再 park）：

```s
_start:
    csrr t0, mhartid
    slli t0, t0, 13
    la   sp, stacks + STACK_SIZE
    add  sp, sp, t0
    
    j os_main

park:
    wfi
    j park

stacks:
    .skip STACK_SIZE * NCPU
```

## 5. 多核心 mutex 測試

### 5.1 測試案例
```c
mutex_t m;
int shared_counter = 0;

void user_task0(void) {  // 將在 hart 0 執行
    while (1) {
        mutex_lock(&m);
        lib_printf("Task0 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        int temp = shared_counter;
        lib_delay(1000);  // 模擬臨界區工作，增加競爭機會
        shared_counter = temp + 1;
        lib_printf("Task0 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
    }
}

void user_task1(void) {  // 將在 hart 1 執行
    while (1) {
        mutex_lock(&m);
        lib_printf("Task1 [hart %d]: counter before = %d\n", r_mhartid(), shared_counter);
        int temp = shared_counter;
        lib_delay(1000);
        shared_counter = temp + 1;
        lib_printf("Task1 [hart %d]: counter after  = %d\n", r_mhartid(), shared_counter);
        mutex_unlock(&m);
    }
}
```

### 5.2 預期行為
- Task0 (hart 0) 和 Task1 (hart 1) 同時競爭 mutex
- 持有鎖的任務執行時，另一個 hart 應在 `while(m->locked){}` 空迴圈忙待機
- 最終 counter 仍是連續遞增，無競爭條件

## 6. 修改清單

| 檔案 | 修改內容 |
|------|----------|
| `task.c` | 加入 per-hart 上下文陣列 |
| `task.h` | 更新結構定義 |
| `timer.c` | 使用 r_mhartid() 初始化 per-hart scratch |
| `os.c` | 每個 hart 都進入排程迴圈 |
| `start.s` | 所有 harts 都進入 os_main |

## 7. 驗證方式

1. 兩個任務同時遞增 counter
2. 確認 counter 無跳號（多核心並髑安全）
3. 觀察 timer_handler 在不同 hart 上的行為
