# 07-Multicore32bit

## Build & Run

```sh
$ make clean
rm -f *.elf

$ make
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv32ima_zicsr -mabi=ilp32 -T os.ld -o os.elf start.s sys.s lib.c timer.c task.c mutex.c os.c user.c

$ make qemu
Press Ctrl-A and then X to exit QEMU
qemu-system-riscv32 -nographic -smp 4 -machine virt -bios none -kernel os.elf
OS start
Task0 [hart 0]: Created!
Task0 [hart 0]: counter before = 0
Task0 [hart 0]: counter after  = 1
Task1 [hart 0]: Created!
Task1 [hart 0]: counter before = 1
Task1 [hart 0]: counter after  = 2
...
```

Features:
- 32-bit RISC-V multicore support
- 5 tasks (Task0-4) running across multiple harts
- Mutex protects shared counter across cores
- Displays hart ID for each task execution
