# 06-Mutex

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
Task0: Created!
Task0: counter before = 0
Task0: counter after  = 1
Task1: Created!
Task1: counter before = 1
Task1: counter after  = 2
...
```

Features:
- Cooperative multitasking with mutex support
- Two tasks (Task0, Task1) share a protected counter
- Mutex ensures atomic access to shared resources
