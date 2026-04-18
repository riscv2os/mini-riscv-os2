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
sleep 15
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
    echo "[PASS] Tasks ran multiple times"
else
    echo "[FAIL] Tasks did not run multiple times"
    exit 1
fi

echo ""
echo "=== Mutex Test ==="

COUNTERS=$(grep -E "^Task[01]: counter after" "$OUTPUT" | sed 's/.*= //')
if [ -z "$COUNTERS" ]; then
    echo "[FAIL] No counter output found"
    exit 1
fi

echo "Counter values observed:"
echo "$COUNTERS"

UNIQUE_COUNTERS=$(echo "$COUNTERS" | sort -n | uniq)
UNIQUE_COUNT=$(echo "$UNIQUE_COUNTERS" | wc -l)
echo "Unique counter values: $UNIQUE_COUNT"

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
