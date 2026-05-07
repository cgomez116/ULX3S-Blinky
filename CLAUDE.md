# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of FPGA projects for the ULX3S open-source board (Lattice ECP5). Each subdirectory is an independent project with its own Makefile. The primary project is a simple LED blinker that runs both in Verilator simulation and on real hardware.

**FPGA variant:** All projects target the **ECP5-85F** (`--85k` in nextpnr). If you have a different board variant, update the `--Xk` flag in each project's Makefile (12k/25k/45k/85k).

## Toolchain

**Synthesis/PnR pipeline:** Yosys → nextpnr-ecp5 → ecppack → ujprog/fujprog  
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

### ButtonPattern (HDMI color bars + button-driven solid colors)
```bash
cd ButtonPattern
make bitstream      # Build ulx3s.bit (targets --85k; change if your board differs)
fujprog ulx3s.bit   # Program board
make clean
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
`blinky.v` uses `` `ifdef VERILATOR `` guards so the same file works for both Verilator simulation and hardware synthesis. Under Verilator the top module is named `blinky`; for hardware it is named `top` — this is intentional and required by the constraint file.

### Testbench Pattern
All projects share the same pattern: `testb.h` is a reusable C++ template that wraps any Verilated module, handles clock toggling, and optionally writes VCD traces. Project-specific testbenches (e.g., `blinky_tb.cpp`) instantiate it.

### HDMI Pipeline (TestPattern / ButtonPattern)
Both HDMI projects share the same layered pipeline:
1. `clock.v` — ECP5 PLL generates 25 MHz (pixel clock) and 250 MHz (TMDS bit clock) from the 25 MHz crystal.
2. `llhdmi.v` — VGA timing state machine (640×480 @ 60 Hz); emits `o_rd`, `o_newline`, `o_newframe` control signals and serializes TMDS words via shift registers clocked at 250 MHz.
3. `TMDS_encoder.v` — 8b/10b TMDS encoder (one instance per RGB channel); maintains DC balance via a running disparity counter.
4. `vgatestsrc.v` — Pixel source; generates the color-bar test pattern. In ButtonPattern, an `i_btn[5:0]` input overrides the pattern with a full-brightness solid color when any button is held.
5. `OBUFDS.v` — Differential output buffer stub for simulation; replaced by ECP5 native cells during synthesis.

### Constraint Files
Pin assignments live in `.lpf` files (Lattice Preference Format). The main board constraint file is `ulx3s_v20.lpf`; HDMI projects use `ulx3s_v20_segpdi.lpf` which adds HDMI differential pair (`gpdi`) and button/LED pin definitions.

### Synthesis Scripts
Each project has a `.ys` Yosys script that reads Verilog sources, synthesizes for ECP5, and emits a JSON netlist. TestPattern and ButtonPattern use `ysgen.sh` to generate the `.ys` file dynamically from a list of source files.
