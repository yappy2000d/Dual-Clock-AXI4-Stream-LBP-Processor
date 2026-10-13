# read_def ../syn/out/CHIP_scan.def

# set_db place_global_max_density 60

set_db place_opt_run_global_place full
place_opt_design

# write_def ../pnr/out/CHIP_scan.def

set_db add_tieoffs_cells {TIELO TIEHI}
set_db add_tieoffs_max_distance 100
set_db add_tieoffs_max_fanout 10
add_tieoffs