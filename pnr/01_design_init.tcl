# Init Design
read_mmmc mmmc.view.stylus

read_physical -lef { \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/INNOVUS_stylus/lef/tsmc18_6lm_cic.lef \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/INNOVUS_stylus/lef/tsmc18_6lm_antenna_cic.lef \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/INNOVUS_stylus/lef/tpb973gv_6lm.lef \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/INNOVUS_stylus/lef/tpz973gv_6lm_cic.lef \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/INNOVUS_stylus/lef/antenna.lef \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/INNOVUS_stylus/lef/antenna_6lm.lef \
    ../ip/rf136x16m4h3v2/rf136x16m4h3v2.vclef \
    ../ip/rf136x16m4h3v2/rf136x16m4h3v2_ant.lef \
}

read_netlist ../syn/out/CHIP_syn.v -top CHIP

set_db init_ground_nets VSS
set_db init_power_nets VDD

init_design

# Connect Global Nets
delete_global_net_connections 
connect_global_net VDD -type pg_pin -pin_base_name VDD -inst_base_name *
connect_global_net VSS -type pg_pin -pin_base_name VSS -inst_base_name *
connect_global_net VDD -type tie_hi -inst_base_name *
connect_global_net VSS -type tie_lo -inst_base_name *

# Design Config
set_db design_process_node 180 
set_db design_flow_effort standard
set_db design_power_effort high
                          
set_db extract_rc_lef_tech_file_map /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/INNOVUS_stylus/FireIce/lefdef.layermap.cmd

create_basic_path_groups -reset
create_basic_path_groups -expanded

set_db design_early_clock_flow true
set_db timing_analysis_type ocv
set_db timing_analysis_cppr both
set_timing_derate -early 0.9 -late 1 -delay_corner {DC_max}
set_timing_derate -early 1 -late 1.1 -delay_corner {DC_min}

set_db cts_use_inverters true
set_db ccopt_auto_limit_insertion_delay_factor 1.05
source cts_config.tcl