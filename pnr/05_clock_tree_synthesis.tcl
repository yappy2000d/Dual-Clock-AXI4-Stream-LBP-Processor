time_design -pre_cts

set_db opt_fix_fanout_load true
opt_design -pre_cts

reset_clock_latency [all_clocks]
clock_opt_design

time_design -post_cts
opt_design -post_cts