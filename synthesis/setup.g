# Setup file for Cadence Genus synthesis solution - December 2025 
# -----------------------------------------------------------------------
# University of California, Irvine - Univesrity of California, Los Angles
# -----------------------------------------------------------------------

# Guard against re-sourcing
if {[info exists ::SETUP_DONE]} {
  puts "ERROR: setup.g has already been sourced in this session"
  return
}
set ::SETUP_DONE 1

puts "\nINFO: Genus SETUP started"

# -----------------------------------------------------------------------------
# Design configuration (EDIT HERE ONLY)
# -----------------------------------------------------------------------------
set ::DESIGN_NAME   route_compute
set ::RTL_FILES     {route_compute.v}
set ::SDC_FILE      /path/to/constraints.sdc

set ::REPORT_DIR    reports
set ::OUTPUT_DIR    outputs

# -----------------------------------------------------------------------------
# Search paths
# -----------------------------------------------------------------------------
set_db init_lib_search_path {/home/software/PDKs/FreePDK45/osu_soc/lib/files}

set_db init_hdl_search_path {/home/delavari/cadence/synthesis/rtl}

# -----------------------------------------------------------------------------
# Tool configuration
# -----------------------------------------------------------------------------
set_db timing_report_unconstrained true

# Debug verbosity from 0 to 9
set_db information_level 9      
# Generate error when cannot map a block (a cell in the library is missing)
set_db hdl_error_on_blackbox true   

# -----------------------------------------------------------------------------
# Libraries (could be more than one)
# -----------------------------------------------------------------------------
read_libs gscl45nm.lib

# -----------------------------------------------------------------------------
# Environment info (debug visibility)
# -----------------------------------------------------------------------------
puts "Hostname       : [info hostname]"
puts "Design name    : $::DESIGN_NAME"
puts "RTL files      : $::RTL_FILES"
puts "SDC file       : $::SDC_FILE"
puts "Library path   : [get_db init_lib_search_path]"

if {[file exists /proc/cpuinfo]} {
  sh grep "model name" /proc/cpuinfo
  sh grep "cpu MHz"    /proc/cpuinfo
}

# -----------------------------------------------------------------------------
# Directory creation
# -----------------------------------------------------------------------------
foreach dir [list $::REPORT_DIR $::OUTPUT_DIR] {
  if {![file exists $dir]} {
    file mkdir $dir
  }
}

puts "INFO: Genus SETUP completed successfully\n"
