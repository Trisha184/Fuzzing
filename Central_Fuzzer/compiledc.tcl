#set search_path "/WORK"

# Suppress warnings about undeclared wires
set suppress_errors {VER-936}

## Setting up target libraries
set_app_var target_library {
    lec25dscc25.db
}
define_design_lib WORK -path ./WORK
## Setting up link libraries
set_app_var link_library $target_library

set my_files [list central_fuzz_fsm.sv wishbone_dual.sv central_top.sv]

analyze -f sverilog $my_files 

set my_toplevel central_top 

elaborate $my_toplevel

set_max_area 0
compile -ungroup_all -area_effort high -map_effort high

report_area
report_hierarchy
report_reference
report_power

write -format verilog -hierarchy -output central_netlist.v central_top

quit