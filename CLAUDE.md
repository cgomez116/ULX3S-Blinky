# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of FPGA projects for the ULX3S open-source board (ECP5 45F FPGA). Each subdirectory is an independent project. The primary project is a simple LED blinker that runs both in Verilator simulation and on real hardware.

## Toolchain

**Synthesis/PnR pipeline:** Yosys → nextpnr-ecp5 → ecppack → ujprog  
**Simulation:** Verilator with C++ testbenches; traces output to `.vcd` files  
**Docker:** All tools are pre-installed in the container (see README-Docker.md)

## Build Commands

### Blinky (root directory)
```bash
make                # Verilator simulation (1M clock cycles, outputs blinky.vcd)
make ulx3s.bit      # Full FPGA bitstream (synthesis → PnR → pack)
make ujprog         # Program the board
make clean
```

### Echo (serial UART echo, 115200 bps)
```bash
cd Echo
make                # Simulate
make ulx3s.bit      # Build bitstream
make prog           # Program board
```

### TestPattern (HDMI test pattern)
```bash
cd TestPattern
make                # Simulate → outputs image.ppm
make bitstream      # Build ulx3s_45f_ULX3S_45F.bit
```

### Docker (when native tools aren't installed)
```bash
./docker-run.sh build           # Build container
./docker-run.sh shell           # Interactive shell
./docker-run.sh make ulx3s.bit  # Run make target in container
./docker-run.sh program         # Program FPGA
./docker-run.sh clean
```

## Architecture

### Conditional Compilation (blinky.v)
`blinky.v` uses `\`ifdef SIMULATION` guards so the same file works for both Verilator simulation (fast counter, no clock primitive) and hardware synthesis (25 MHz external clock, real counter bit widths).

### Testbench Pattern
All projects share the same pattern: `testb.h` is a reusable C++ template that wraps any Verilated module, handles clock toggling, and optionally writes VCD traces. Project-specific testbenches (e.g., `blinky_tb.cpp`) instantiate it.

### Constraint Files
Pin assignments live in `.lpf` files (Lattice Preference Format). The main board constraint file is `ulx3s_v20.lpf`; TestPattern uses `ulx3s_v20_segpdi.lpf` which adds HDMI differential pairs.

### Synthesis Scripts
Each project has a `.ys` Yosys script that reads the Verilog sources, synthesizes for ECP5, and writes a JSON netlist. TestPattern uses a shell script (`ysgen.sh`) to generate its `.ys` file dynamically due to its larger source list.

## Key Files
- `blinky.v` — Top-level design (dual simulation/hardware)
- `blinky_tb.cpp` — C++ testbench entry point
- `testb.h` — Reusable Verilator testbench template
- `blinky.ys` — Yosys synthesis script
- `ulx3s_v20.lpf` — Board pin constraints
- `Dockerfile` / `docker-compose.yml` — Containerized toolchain
- `docker-run.sh` — Convenience wrapper for Docker workflows
