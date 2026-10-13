set top CHIP

file mkdir ./work ./rpt ./out

define_design_lib WORK -path ./work
set_svf "./out/${top}_syn.svf"

if { [analyze -format verilog \
    -library WORK \
    { ../rtl/CORE.v ../rtl/CHIP.v }
] == 0 } {
    exit 1
}

elaborate $top -arch verilog -lib WORK
current_design $top

if { [link] == 0 } { exit 1 }

uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

if { [check_design] == 0 } { exit 1 }

set_operating_conditions -min fastcold -max slow
set_wire_load_model -name tsmc18_wl10 -library slow

source -echo -verbose "${top}_syn.sdc"
check_timing

set RESET_SYNC_REGS [get_cells -hierarchical -filter {
       full_name =~ "*u_creset_sync/sync_ff1_reg*"
    || full_name =~ "*u_creset_sync/sync_ff2_reg*"
    || full_name =~ "*u_areset_sync/sync_ff1_reg*"
    || full_name =~ "*u_areset_sync/sync_ff2_reg*"
}]

set_dont_retime $RESET_SYNC_REGS true

set_cost_priority -min_delay
set compile_ultra_ungroup_dw true
set_optimize_registers true

compile_ultra -retime

set RESET_SYNC_REGS_MAPPED [get_cells -hierarchical -filter {
       full_name =~ "*u_creset_sync/sync_ff1_reg*"
    || full_name =~ "*u_creset_sync/sync_ff2_reg*"
    || full_name =~ "*u_areset_sync/sync_ff1_reg*"
    || full_name =~ "*u_areset_sync/sync_ff2_reg*"
}]
set_dont_touch $RESET_SYNC_REGS_MAPPED true

optimize_netlist -area

compile_ultra -inc

report_qor  > ./rpt/qor.txt
report_area > ./rpt/area.txt
report_timing -delay_type max > ./rpt/timing_max.txt
report_timing -delay_type min > ./rpt/timing_min.txt
report_power > ./rpt/power.txt
report_net_fanout -high_fanout > ./rpt/fanout.txt

remove_unconnected_ports -blast_buses [get_cells * -hier]
change_names -hierarchy -rules name_rule

write -format ddc     -hier -output "./out/${top}_syn.ddc"
write -format verilog -hier -output "./out/${top}_syn.v"
write_sdc "./out/${top}_syn.sdc"
write_sdf -context verilog -load_delay net "./out/${top}_syn.sdf"
set_svf -off

quit