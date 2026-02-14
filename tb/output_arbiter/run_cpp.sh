#!/bin/bash

# Output Arbiter C++ Testbench Runner for Verilator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_DIR="$SCRIPT_DIR/../../rtl"

echo "Building output_arbiter testbench..."

# Clean previous build
rm -rf "$SCRIPT_DIR/obj_dir"

# Run Verilator
verilator -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-LATCH --trace -cc \
    "$RTL_DIR/output_arbiter.v" \
    --exe "$SCRIPT_DIR/output_arbiter_tb.cpp" \
    -Mdir "$SCRIPT_DIR/obj_dir"

# Build
make -C "$SCRIPT_DIR/obj_dir" -f Voutput_arbiter.mk Voutput_arbiter

echo "Running output_arbiter testbench..."

# Run
"$SCRIPT_DIR/obj_dir/Voutput_arbiter"

echo "Waveform saved to output_arbiter.vcd"
