#!/bin/bash

set -e

echo "Building OS..."
make clean
make os.elf

echo ""
echo "Running QEMU test..."
OUTPUT=$(mktemp)

qemu-system-riscv32 -nographic -smp 4 -machine virt -bios none -kernel os.elf > "$OUTPUT" 2>&1 &
QEMU_PID=$!
sleep 3
kill $QEMU_PID 2>/dev/null || true
wait $QEMU_PID 2>/dev/null || true

echo "=== Output (last 50 lines) ==="
tail -50 "$OUTPUT"

echo ""
echo "=== Test Analysis ==="

TASK0_RUNS=$(grep -c "Task0 \[hart" "$OUTPUT" 2>/dev/null || true)
TASK1_RUNS=$(grep -c "Task1 \[hart" "$OUTPUT" 2>/dev/null || true)
TASK2_RUNS=$(grep -c "Task2 \[hart" "$OUTPUT" 2>/dev/null || true)
TASK3_RUNS=$(grep -c "Task3 \[hart" "$OUTPUT" 2>/dev/null || true)
TASK4_RUNS=$(grep -c "Task4 \[hart" "$OUTPUT" 2>/dev/null || true)

TASK0_RUNS=${TASK0_RUNS:-0}
TASK1_RUNS=${TASK1_RUNS:-0}
TASK2_RUNS=${TASK2_RUNS:-0}
TASK3_RUNS=${TASK3_RUNS:-0}
TASK4_RUNS=${TASK4_RUNS:-0}

TOTAL_RUNNING=0
[ "$TASK0_RUNS" -gt 0 ] && TOTAL_RUNNING=$((TOTAL_RUNNING + 1))
[ "$TASK1_RUNS" -gt 0 ] && TOTAL_RUNNING=$((TOTAL_RUNNING + 1))
[ "$TASK2_RUNS" -gt 0 ] && TOTAL_RUNNING=$((TOTAL_RUNNING + 1))
[ "$TASK3_RUNS" -gt 0 ] && TOTAL_RUNNING=$((TOTAL_RUNNING + 1))
[ "$TASK4_RUNS" -gt 0 ] && TOTAL_RUNNING=$((TOTAL_RUNNING + 1))

echo "Task0 running count: $TASK0_RUNS"
echo "Task1 running count: $TASK1_RUNS"
echo "Task2 running count: $TASK2_RUNS"
echo "Task3 running count: $TASK3_RUNS"
echo "Task4 running count: $TASK4_RUNS"

if [ "$TOTAL_RUNNING" -ge 2 ]; then
    echo "[PASS] Found $TOTAL_RUNNING tasks running"
else
    echo "[FAIL] Only $TOTAL_RUNNING tasks running (expected at least 2)"
    exit 1
fi

echo ""
echo "=== Mutex Test ==="

COUNTERS=$(grep -E "Task[0-9] \[hart.*counter after" "$OUTPUT" | sed 's/.*= //')
if [ -z "$COUNTERS" ]; then
    echo "[FAIL] No counter output found"
    exit 1
fi

UNIQUE_COUNTERS=$(echo "$COUNTERS" | sort -n | uniq)
UNIQUE_COUNT=$(echo "$UNIQUE_COUNTERS" | wc -l | tr -d ' ')
echo "Counter values: $UNIQUE_COUNT unique values"

SEQUENCE_OK=true
PREV=0
for VAL in $(echo "$UNIQUE_COUNTERS"); do
    if [ "$VAL" -eq $((PREV + 1)) ] || [ "$VAL" -eq 1 ]; then
        :
    elif [ "$VAL" -gt $((PREV + 1)) ]; then
        echo "  [WARN] Gap detected: expected $((PREV + 1)), got $VAL"
        SEQUENCE_OK=false
    fi
    PREV=$VAL
done

if [ "$SEQUENCE_OK" = true ]; then
    echo "[PASS] Counter values are in correct sequence"
else
    echo "[FAIL] Counter values show gaps (possible race condition)"
    exit 1
fi

echo ""
echo "=== All tests passed ==="
rm -f "$OUTPUT"
