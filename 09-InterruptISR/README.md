# 09-InterruptISR

## Build & Run

```sh
$ make clean
rm -f *.elf

$ make
riscv64-unknown-elf-gcc -nostdlib -fno-builtin -mcmodel=medany -march=rv64ima_zicsr -mabi=lp64 -T os.ld -o os.elf start.s sys.s lib.c timer.c task.c mutex.c os.c user.c isr.c

$ make qemu
Press Ctrl-A and then X to exit QEMU
qemu-system-riscv64 -nographic -smp 4 -machine virt -bios none -kernel os.elf
OS start
Task0 [hart 0]: Created!
Task0 [hart 0]: counter before = 0
Task0 [hart 0]: counter after  = 1
Task4: registering ISR for IRQ 5...
Task4: ISR registered, call_count=0
Task4 [hart 0]: ISR called! count=1
Task4 [hart 0]: counter before = 1
Task4 [hart 0]: counter after  = 2
...
```

Features:
- 64-bit RISC-V multicore support (rv64ima)
- 5 tasks (Task0-4) running across multiple harts
- ISR (Interrupt Service Routine) registration system
- Task4 registers a custom timer ISR for IRQ 5
- Mutex protects shared counter across cores
