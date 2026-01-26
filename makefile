# User-selectable options
sim     ?=
module  ?=
src  ?= cpp

# Sanity checks
ifeq ($(module),)
$(error ERROR: 'module' is not set. Use: make -sim=... -module=...)
endif

ifeq ($(sim),)
$(error ERROR: 'sim' is not set. Use: make -sim=iverilog or -sim=verilator)
endif

# Common paths
TB_DIR      := tb/$(module)
RTL_DIR     := rtl
IVERILOG_OUT:= $(TB_DIR)/$(module).vvp

# Default target
.PHONY: all
all:
ifeq ($(sim),iverilog)
	$(MAKE) run_iverilog
else ifeq ($(sim),verilator)
	$(MAKE) run_verilator
else
	$(error Unsupported simulator: $(sim))
endif

# Icarus Verilog flow
.PHONY: run_iverilog
run_iverilog:
	iverilog -o $(IVERILOG_OUT) -I$(RTL_DIR) $(TB_DIR)/$(module)_tb.v
	vvp $(IVERILOG_OUT)

# Verilator flow
WARNING_OPTIONS ?= -Wno-WIDTHEXPAND
OBJ_DIR := obj_dir

.PHONY: run_verilator
run_verilator:
ifeq ($(src),cpp)
	verilator -Wno-WIDTHEXPAND --trace -cc $(module).v --exe $(module)_tb.cpp
	$(MAKE) -C $(OBJ_DIR) -f V$(module).mk V$(module)
	./$(OBJ_DIR)/V$(module)
else ifeq ($(src),verilog)
	verilator -Wno-UNOPTFLAT $(module).v --top $(module) --trace --timing --binary -j 4
	$(MAKE) -C $(OBJ_DIR) -f V$(module).mk V$(module)
	./$(OBJ_DIR)/V$(module)
	rm -rf $(OBJ_DIR)
else
	$(error Unsupported src type: $(src))
endif

# Cleanup
.PHONY: clean
clean:
	rm -rf $(OBJ_DIR) $(IVERILOG_OUT)
