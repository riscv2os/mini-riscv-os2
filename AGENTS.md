# mini-riscv-os Agent Instructions

## Project Structure
- 9 sequential tutorial stages: `01-HelloOs/` through `09-InterruptISR/`
- Each directory is self-contained with its own Makefile
- No root-level build system; work within a specific stage directory

## Build & Run
```sh
cd 01-HelloOs  # or any other stage
make           # builds os.elf
make qemu      # runs in QEMU
# Exit QEMU: Ctrl-A then X
```

## Toolchain
- Uses `riscv64-unknown-elf-gcc` (even for 32-bit targets)
- Requires: QEMU with riscv32/riscv64 support, RISC-V cross-compiler

## Key Differences by Stage
| Stage | Architecture | QEMU |
|-------|--------------|------|
| 01-05 | 32-bit (rv32ima) | qemu-system-riscv32 |
| 06-09 | 64-bit (rv64ima) | qemu-system-riscv64 |

## Common Makefile Targets
- `make` - build os.elf
- `make qemu` - run in QEMU
- `make clean` - remove .elf files