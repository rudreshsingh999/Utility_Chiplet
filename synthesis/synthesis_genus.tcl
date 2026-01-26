# Synthesis script for Cadence Genus - December 2025 
# -----------------------------------------------------------------------
# University of California, Irvine - Univesrity of California, Los Angles
# -----------------------------------------------------------------------

puts "\n========== Synthesis started =========="

read_hdl $::RTL_FILES
elaborate
timestat Elaboration
# Check for unresolved refs & empty modules
check_design -unresolved   

read_sdc $::SDC_FILE

# # Apply design constraints for logic synthesis
# # Define clock with 1000ps period, no external timing slack, clock transition time (slew rate) of 100ps
# set_clock [define_clock -period 1000 -name ${clkpin} [clock_ports]]
# set_input_delay -clock ${clkpin} 0 [vfind /designs/${DESIGN}/ports -port *]
# set_output_delay -clock ${clkpin} 0 [vfind /designs/${DESIGN}/ports -port *]
# dc::set_clock_transition .1 ${clkpin}

# Effort levels
set_db syn_generic_effort high
set_db syn_map_effort     high
set_db syn_opt_effort     high

# Run synthesis
syn_generic
syn_map
syn_opt

puts "========== Synthesis completed ==========\n"

# -----------------------------------------------------------------------------
# Reports
# -----------------------------------------------------------------------------

report_timing -lint

report_timing -unconstrained > $::REPORT_DIR/report_timing.rpt
report_power                 > $::REPORT_DIR/report_power.rpt
report_area                  > $::REPORT_DIR/report_area.rpt
report_qor                   > $::REPORT_DIR/report_qor.rpt
report datapath              > $::REPORT_DIR/report_datapath.rpt
report gates                 > $::REPORT_DIR/report_gates.rpt

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
write_db -common
write_hdl  > $::OUTPUT_DIR/${::DESIGN_NAME}_netlist.v
write_sdc  > $::OUTPUT_DIR/${::DESIGN_NAME}.sdc
write_sdf  -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > $::OUTPUT_DIR/${::DESIGN_NAME}.sdf