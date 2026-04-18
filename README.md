# mini-riscv-os

A minimal multi-tasking OS kernel for RISC-V from scratch, 9 sequential stages from basic boot to 64-bit multicore.

Inspired by [jserv](https://github.com/jserv)'s [mini-arm-os](https://github.com/jserv/mini-arm-os).

## Stages

| # | Directory | Description |
|---|-----------|-------------|
| 01 | [01-HelloOs](01-HelloOs) | UART output, stack setup |
| 02 | [02-ContextSwitch](02-ContextSwitch) | Manual context switch in assembly |
| 03 | [03-MultiTasking](03-MultiTasking) | Cooperative multi-tasking |
| 04 | [04-TimerInterrupt](04-TimerInterrupt) | Timer interrupt, CLINT, CSR |
| 05 | [05-Preemptive](05-Preemptive) | Preemptive scheduling, time slicing |
| 06 | [06-Mutex](06-Mutex) | Mutex, spinlock, critical sections |
| 07 | [07-Multicore32bit](07-Multicore32bit) | 32-bit SMP, multi-core |
| 08 | [08-Multicore64bit](08-Multicore64bit) | 64-bit RISC-V, LP64 ABI |
| 09 | [09-InterruptISR](09-InterruptISR) | ISR framework, dynamic registration |

## Build & Run

```sh
cd 01-HelloOs  # or any other stage
make           # build os.elf
make qemu      # run in QEMU
# Exit QEMU: Ctrl-A then X
```

## Requirements

- `riscv64-unknown-elf-gcc` (works for both 32-bit and 64-bit targets)
- QEMU with RISC-V support (`qemu-system-riscv32` / `qemu-system-riscv64`)

## Architecture

- **32-bit stages (01-05)**: rv32ima, ILP32 ABI, `qemu-system-riscv32`
- **64-bit stages (06-09)**: rv64ima, LP64 ABI, `qemu-system-riscv64`

## License

BSD 2-clause - see [LICENSE](LICENSE)