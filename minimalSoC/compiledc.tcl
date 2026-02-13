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

set my_files [list top.v picorv32.v picorv32_top.v aes_192.v aes_top.v round.v table.v wbram.v wb_bus_b3.sv wb_decode.sv wb_interconnect_arb_rr.sv wb_mux.sv]


analyze -f sverilog $my_files 

set my_toplevel top

elaborate $my_toplevel

set_max_area 0


compile -ungroup_all -area_effort high -map_effort high

report_area
report_hierarchy
report_reference
report_power

write -format verilog -hierarchy -output top_netlist.v top

quit