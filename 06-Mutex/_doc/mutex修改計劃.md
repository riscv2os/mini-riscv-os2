# Mutex 實作計劃

## 1. 設計目標

在現有搶先式多工系統上加入 Mutex，實現互斥鎖功能，防止競爭條件（race condition）。

## 2. Mutex API 設計

```c
// mutex.h
typedef struct {
    int locked;           // 0: unlocked, 1: locked
    int owner;            // 擁有者的 task id (-1 表示無)
    int blocked_count;     // 等待中的任務數量
} mutex_t;

void mutex_init(mutex_t *m);
void mutex_lock(mutex_t *m);
void mutex_unlock(mutex_t *m);
```

## 3. 實作要點

### 3.1 mutex_lock()
```
if (locked == 0) {
    locked = 1;
    owner = current_task;
} else {
    // 鎖已被持有，將自己加入等待佇列並切換到 OS
    blocked_count++;
    task_os();  // 讓出 CPU
}
```

### 3.2 mutex_unlock()
```
if (owner == current_task) {
    owner = -1;
    locked = 0;
    // 喚醒一個等待中的任務（可選：簡化版不實現）
}
```

## 4. 測試案例設計

建立一個共享資源 `shared_counter`，讓 task0 和 task1 同時競爭 mutex 並遞增計數器，觀察最終結果是否正確。

```c
mutex_t m;
int shared_counter = 0;

void user_task0(void) {
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

void user_task1(void) {
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
```

**預期行為**：
- 有 mutex：counter 每次遞增 1
- 無 mutex：counter 可能跳過值（競爭導致）

## 5. 預期輸出（有 Mutex）

計時器會輪流切換 task，交錯執行：

```
OS start
OS: Activate next task
Task0: Created!
Task0: counter before = 0
Task0: counter after  = 1
timer_handler: 1      ← 計時器中斷，切換到 Task1
OS: Activate next task
Task1: Created!
Task1: counter before = 1    ← Task1 拿到鎖，看到正確值
Task1: counter after  = 2
timer_handler: 2      ← 切換回 Task0
Task0: counter before = 2     ← Task0 拿到鎖，看到正確值
Task0: counter after  = 3
timer_handler: 3      ← 切換到 Task1
Task1: counter before = 3
Task1: counter after  = 4
...
```

**關鍵**：counter 每次遞增 1，不會跳號。若無 mutex，可能出現：
```
Task0: counter before = 0
Task1: counter before = 0   ← Task0 尚未寫入，Task1 就讀到舊值
Task0: counter after  = 1
Task1: counter after  = 2   ← 錯誤：應該是 1→2，但實際是 0→2
```

## 6. 實作步驟

| 步驟 | 檔案 | 內容 |
|------|------|------|
| 1 | `mutex.h` | 定義 mutex_t 結構和 API |
| 2 | `mutex.c` | 實作 mutex_init/lock/unlock |
| 3 | `user.c` | 加入共享資源和 mutex 測試 |
| 4 | `Makefile` | 加入 mutex.c 編譯 |

## 7. 檔案新增/修改清單

- 新增：`mutex.h`, `mutex.c`
- 修改：`user.c`, `Makefile`
