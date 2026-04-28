# ULX3S FPGA Development Container
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3 \
    python3-dev \
    python3-pip \
    libboost-all-dev \
    libeigen3-dev \
    qtbase5-dev \
    libqt5svg5-dev \
    tcl-dev \
    libreadline-dev \
    bison \
    flex \
    pkg-config \
    libffi-dev \
    verilator \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --upgrade pip && \
    pip3 install setuptools wheel cmake

# Clone and build Yosys
RUN git clone https://github.com/YosysHQ/yosys.git /tmp/yosys && \
    cd /tmp/yosys && \
    git submodule update --init && \
    make -j2 && \
    make install && \
    cd / && rm -rf /tmp/yosys

# Clone and build project-trellis
RUN git clone https://github.com/YosysHQ/prjtrellis.git /tmp/prjtrellis && \
    cd /tmp/prjtrellis && \
    git submodule update --init && \
    cd libtrellis && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local . && \
    make -j2 && \
    make install && \
    cd / && rm -rf /tmp/prjtrellis

# Clone and build nextpnr
RUN git clone https://github.com/YosysHQ/nextpnr.git /tmp/nextpnr && \
    cd /tmp/nextpnr && \
    mkdir build && cd build && \
    cmake -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX=/usr/local \
          -DPYTHON_EXECUTABLE=/usr/bin/python3 \
          -DBUILD_TESTS=OFF .. && \
    make -j2 && \
    make install && \
    cd / && rm -rf /tmp/nextpnr

# Install openFPGALoader
RUN apt-get update && apt-get install -y \
    libftdi1-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    && rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/trabucayre/openFPGALoader.git /tmp/openfpgaloader && \
    cd /tmp/openfpgaloader && \
    mkdir build && cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/openfpgaloader

# Create working directory
RUN mkdir -p /workspace
WORKDIR /workspace

# Set environment variables
ENV PYTHONPATH=/usr/local/lib/python3/dist-packages:$PYTHONPATH

# Default command
CMD ["/bin/bash"]