#!/bin/bash

set -e

echo "Building OS..."
make clean
make os.elf

echo "Running QEMU test..."
OUTPUT=$(mktemp)

qemu-system-riscv32 -nographic -smp 4 -machine virt -bios none -kernel os.elf > "$OUTPUT" 2>&1 &
QEMU_PID=$!

sleep 10
kill $QEMU_PID 2>/dev/null || true
wait $QEMU_PID 2>/dev/null || true

echo "=== Output ==="
cat "$OUTPUT"

echo ""
echo "=== Test Analysis ==="

if grep -q "Task0: Created!" "$OUTPUT" && grep -q "Task1: Created!" "$OUTPUT"; then
    echo "[PASS] Both tasks were created"
else
    echo "[FAIL] Tasks were not created properly"
    exit 1
fi

TASK0_RUNS=$(grep -c "^Task0:" "$OUTPUT" || echo "0")
TASK1_RUNS=$(grep -c "^Task1:" "$OUTPUT" || echo "0")

echo "Task0 running count: $TASK0_RUNS"
echo "Task1 running count: $TASK1_RUNS"

if [ "$TASK0_RUNS" -ge 2 ] && [ "$TASK1_RUNS" -ge 2 ]; then
    echo "[PASS] Tasks ran multiple times (not restarting from beginning)"
else
    echo "[FAIL] Tasks did not run multiple times (may be restarting from beginning)"
    exit 1
fi

echo ""
echo "=== All tests passed ==="
rm -f "$OUTPUT"
