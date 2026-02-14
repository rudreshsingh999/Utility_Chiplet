#!/bin/bash

# Credit Manager C++ Testbench Runner for Verilator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_DIR="$SCRIPT_DIR/../../rtl"

echo "Building credit_manager testbench..."

# Clean previous build
rm -rf "$SCRIPT_DIR/obj_dir"

# Run Verilator
verilator -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC --trace -cc \
    "$RTL_DIR/credit_manager.v" \
    --exe "$SCRIPT_DIR/credit_manager_tb.cpp" \
    -Mdir "$SCRIPT_DIR/obj_dir"

# Build
make -C "$SCRIPT_DIR/obj_dir" -f Vcredit_manager.mk Vcredit_manager

echo "Running credit_manager testbench..."

# Run
"$SCRIPT_DIR/obj_dir/Vcredit_manager"

echo "Waveform saved to credit_manager.vcd"
