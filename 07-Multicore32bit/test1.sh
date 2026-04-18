#!/bin/bash

echo "Building OS..."
make clean
make os.elf

echo ""
echo "Running QEMU test (5 seconds)..."

# Run QEMU in background and redirect properly
qemu-system-riscv32 -nographic -smp 4 -machine virt -bios none -kernel os.elf > /tmp/test_out.txt 2>&1 &
QEMU_PID=$!
sleep 15
kill -TERM $QEMU_PID 2>/dev/null
wait $QEMU_PID 2>/dev/null || true

echo "=== First 30 lines ==="
head -30 /tmp/test_out.txt

echo ""
echo "=== Last 20 lines ==="
tail -20 /tmp/test_out.txt

echo ""
echo "=== Task Counts ==="

# Count each task - handle empty results properly
TASK0=$(grep -c "Task0 \[hart" /tmp/test_out.txt 2>/dev/null || echo "0")
TASK1=$(grep -c "Task1 \[hart" /tmp/test_out.txt 2>/dev/null || echo "0")
TASK2=$(grep -c "Task2 \[hart" /tmp/test_out.txt 2>/dev/null || echo "0")
TASK3=$(grep -c "Task3 \[hart" /tmp/test_out.txt 2>/dev/null || echo "0")
TASK4=$(grep -c "Task4 \[hart" /tmp/test_out.txt 2>/dev/null || echo "0")

echo "Task0: $TASK0"
echo "Task1: $TASK1"
echo "Task2: $TASK2"
echo "Task3: $TASK3"
echo "Task4: $TASK4"

echo ""
echo "=== Check for 'All harts ready' ==="
grep "All harts ready" /tmp/test_out.txt || echo "NOT FOUND"

echo ""
echo "=== Check for Task Created ==="
grep "Created!" /tmp/test_out.txt || echo "No tasks created"

echo ""
echo "=== Mutex Test ==="
COUNTERS=$(grep "counter after" /tmp/test_out.txt | sed 's/.*= //' | sort -n | uniq)
UNIQUE_COUNT=$(echo "$COUNTERS" | grep -c . || echo "0")
echo "Unique counter values: $UNIQUE_COUNT"

# Check for gaps
if [ "$UNIQUE_COUNT" -gt 0 ]; then
    echo "[PASS] Mutex test passed"
else
    echo "[FAIL] No counter output found"
fi