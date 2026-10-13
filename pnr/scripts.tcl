read_power_rail_results -power_db power.db -rail_directory PD_25C_avg_1/VDD

write_stream CHIP.gds -map_file streamOut.map -lib_name DesignLib \
  -merge { \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/GDS/tsmc18.gds2 \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/GDS/tpz973gv_tpb973gv.gds \
    /process/T18/IP/CBDK_TSMC018_Arm_v4.0/CIC/GDS/tsmc18_corner_tag.gds \
    ../ip/rf136x16m4h3v2/rf136x16m4h3v2.gds2 \
  } -uniquify_cell_names -unit 1000 -mode all

write_sdf CHIP_pnr.sdf -version 2.1 -max_view AV_func_max -typical_view AV_func_max -min_view AV_func_min -recompute_delaycal -target_application verilog -map_setuphold split -map_recrem split -map_removal
sed 's/(RECOVERY /(SETUP /g' ../../pnr/CHIP_pnr.sdf > ../../pnr/CHIP_pnr_vcs.sdf