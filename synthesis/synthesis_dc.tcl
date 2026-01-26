# Synthesis TCL Script for Synopsys Design Compiler - December 2025 
# -----------------------------------------------------------------------
# University of California, Irvine - Univesrity of California, Los Angles

# To run the synthesis script, run this command in terminal
# ---------------------------------------------------------
#              dc_shell-t -f synthesis_dc.tcl             #
# ---------------------------------------------------------

# All verilog files, separated by spaces
set my_verilog_files [list FILE1.v FILE2.v]

# Define top-level module
set my_toplevel TOP_MODULE_NAME_HERE

# The name of the clock pin. If no clock-pin exists, pick anything
set my_clock_pin clk

# Target frequency for optimization (in MHz)
set my_clk_freq_MHz 1000

# Delay of input signals (clock-to-Q, Package etc.)
set my_input_delay_ns 0.1

# Reserved time for output signals (holdtime, [SuperCHIPS] I/O, etc.)
set my_output_delay_ns 0.1


# Setup Library Files
set link_library   "/home/path/to/lib/tech.db"
set target_library "/home/path/to/lib/tech.db"


# Setup the local design library
define_design_lib WORK -path ./WORK


# General Optimization Options
#----------------------------------------------
set verilogout_show_unconnected_pins true
# Enable the ultra optimization engine
set_ultra_optimization true
set_ultra_optimization -force
# Allow register merging when logic permits
set compile_enable_register_merging true
# Propagate constants through sequential logic
set compile_seqmap_propagate_constants true



# Analyze and elaboration
analyze -f verilog $my_verilog_files
elaborate $my_toplevel
current_design $my_toplevel


# Link and uniquify modules
link
uniquify


# Clock Definition & Constraints
set my_period [expr 1000.0 / $my_clk_freq_MHz]

set find_clock [find port [list $my_clock_pin]]
if { $find_clock != [list] } {
    set clk_name $my_clock_pin
    create_clock -period $my_period $clk_name
} else {
    set clk_name vclk
    create_clock -period $my_period -name $clk_name
}

# Add clock uncertainty for PVT and CTS margin
set_clock_uncertainty 0.05 $clk_name

# (FYI) Constraint related commands:
# set_min_library
# set_operating_conditions
# set_wire_load_model
# set_wire_load_mode
# set_wire_load_min_block_size
# set_wire_load_selection_group
# set_clock_uncertainty
# set_clock_transition
# set_drive
# set_load
# set_port_fanout_number
# set_resistance

# Treat clock as ideal during synthesis (pre-CTS)
set_ideal_network [get_clocks $clk_name]


# I/O drive and delay options (optional but recommended for realistic results)
set_driving_cell -lib_cell INVX1 [all_inputs]

set_input_delay $my_input_delay_ns -clock $clk_name \
    [remove_from_collection [all_inputs] $my_clock_pin]

set_output_delay $my_output_delay_ns -clock $clk_name [all_outputs]

# Preserving the clock network after CTS:
# set_dont_touch_network [all_inputs]
# set_dont_touch_network [all_outputs]

# Limit excessive buffering on long nets:
# set_max_transition   0.2 [current_design]
# set_max_capacitance  0.2 [current_design]

# Control fanout to avoid area explosion:
# set_max_fanout 32 [current_design]
# Allow register retiming if it improves timing:
# set_optimize_registers true


# Compile design
# ------------------------------------------------------------------
compile_ultra -no_autoungroup -timing_high_effort_script -gate_clock
# ------------------------------------------------------------------
# -no_autoungroup keeps hierarchy unless explicitly flattened
# -timing_high_effort_script enables aggressive path restructuring
# -gate_clock allows safe automatic clock gating insertion
# ------------------------------------------------------------------

# Other compile options (alternative flows)
# ------------------------------------------------------------------
# compile_ultra -area_effort                 
# compile -ungroup_all -map_effort medium
# compile -incremental_mapping -map_effort medium


check_design
report_constraint -all_violators

# Generate netlist/sdc/db files (.v or .vh or .sv)
write -f verilog -hierarchy -output "${my_toplevel}.vh"
write_sdc "${my_toplevel}.sdc"
write -f db -hierarchy -output "${my_toplevel}.db"


# Export synthesis reports
file mkdir reports
# redirect reports/design.rep     { report_design }
# redirect reports/constraint.rep { report_constraint -all_violators }
# redirect reports/timing_n.rep   { report_timing -nworst 10}

redirect reports/timing.rep     { report_timing -significant_digits 3 }
redirect reports/cell.rep       { report_cell }
redirect reports/area.rep       { report_area -hier }

# For power analysis using DC it is strongly suggested to use switching activity files (SAIF)!
# Convert your .vcd output to .siaf using this command:
# --------------------------------------------------------------------------------------------
#                      vcd2saif -input file.vcd -output file.saif                            #
# --------------------------------------------------------------------------------------------
# Then us the following commands to extract the saif-base power consuption:
# read_saif -input file.saif -instance TOP_MODULE_NAME_HERE/uut
# redirect reports/power_saif.rep { report_power -analysis_effort high -hier }

redirect reports/power.rep      { report_power -hier }

# (FYI) Reporting commands: 
# report_annotated_delay
# report_area
# report_attribute
# report_bus
# report_cache
# report_cell
# report_clock
# report_clusters
# report_compile_options
# report_constraint
# report_delay_calculation
# report_design
# report_design_lib
# report_fsm
# report_hierarchy
# report_internal_loads
# report_lib
# report_name_rules
# report_net
# report_path_group
# report_port
# report_power
# report_qor
# report_reference
# report_resources
# report_synlib
# report_timing
# report_timing_requirements
# report_transitive_fanin
# report_transitive_fanout
# report_wire_load

quit