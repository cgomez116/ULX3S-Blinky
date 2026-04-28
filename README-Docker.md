# ULX3S FPGA Development Container

This container provides a complete FPGA development environment for the ULX3S board, including all necessary tools pre-built and ready to use.

## What's Included

- **Yosys** - Verilog synthesis
- **nextpnr-ecp5** - Place and route for ECP5 FPGAs
- **prjtrellis** - ECP5 database and ecppack bitstream generator
- **openFPGALoader** - FPGA programming tool
- All dependencies (Boost, Python, etc.)

## Quick Start

### 1. Build the Container
```bash
./docker-run.sh build
```

### 2. Build Your FPGA Design
```bash
./docker-run.sh make ulx3s.bit
```

### 3. Program the FPGA
Connect your ULX3S board via USB, then:
```bash
./docker-run.sh program
```

## Alternative Usage

### Interactive Shell
```bash
./docker-run.sh shell
```
This gives you a bash shell inside the container where you can run commands manually.

### Direct Make Commands
```bash
./docker-run.sh make clean
./docker-run.sh make ulx3s.bit
```

## Manual Docker Commands

If you prefer using Docker directly:

### Build
```bash
docker-compose build
```

### Run Commands
```bash
# Synthesis
docker-compose run --rm fpga-dev yosys blinky.ys

# Place & Route
docker-compose run --rm fpga-dev nextpnr-ecp5 --85k --json blinky.json --package CABGA381 --lpf ulx3s_v20.lpf --textcfg ulx3s_out.config

# Bitstream
docker-compose run --rm fpga-dev ecppack ulx3s_out.config ulx3s.bit

# Program
docker-compose run --rm fpga-dev openFPGALoader -b ulx3s ulx3s.bit
```

## Requirements

- Docker installed and running
- USB access for FPGA programming (container has `--privileged` and device passthrough)

## Troubleshooting

### USB Device Not Found
Make sure your ULX3S board is connected and the container has USB access.

### Permission Issues
The container runs with privileged access to enable USB programming.

### Build Issues
If the build fails, try:
```bash
docker system prune -a
./docker-run.sh clean
./docker-run.sh build
```

## File Structure

- `Dockerfile` - Container definition
- `docker-compose.yml` - Docker Compose configuration
- `docker-run.sh` - Convenience script for common operations
- `Makefile` - FPGA build rules
- `blinky.v` - Verilog source
- `blinky.ys` - Yosys synthesis script
- `ulx3s_v20.lpf` - Pin constraints

## Benefits of Containerization

- **Reproducible** - Same environment everywhere
- **Isolated** - No conflicts with system packages
- **Portable** - Works on any system with Docker
- **Version Controlled** - Environment defined as code
- **Clean** - Easy to remove and rebuild

Happy FPGA hacking! 🚀