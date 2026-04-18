#include "mutex.h"

void mutex_init(mutex_t *m) {
    m->locked = 0;
}

void mutex_lock(mutex_t *m) {
    while (1) {
        while (m->locked) {}
        if (__sync_bool_compare_and_swap(&m->locked, 0, 1)) {
            return;
        }
    }
}

void mutex_unlock(mutex_t *m) {
    m->locked = 0;
}
