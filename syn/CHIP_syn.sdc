#===============================================================================
# CHIP_dc_final.sdc
# Design Compiler constraints
#
# Assumptions
#   - cclk: 5 ns core clock (200 MHz)
#   - aclk: 15 ns AXI clock (66.667 MHz)
#   - aclk and cclk are externally generated, nominally phase-aligned
#   - cresetn and aresetn assert asynchronously and deassert through two-stage synchronizers
#   - AXI external logic gets half an AXI cycle; CHIP gets the other half
#   - PLL has not been selected yet; uncertainty values are provisional margins
#
# Clock-topology requirement:
#   DC must preserve the physical input-pad topology:
#       cclk -> ipad_cclk -> i_cclk -> internal core-clock sinks
#       aclk -> ipad_aclk -> i_aclk -> internal AXI-clock sinks
#   Clock networks remain ideal in DC; CTS is performed later in Innovus.
#===============================================================================

set CORE_PERIOD       5.000
set AXI_PERIOD       15.000
set AXI_IO_MAX_DELAY  7.500
set AXI_IO_MIN_DELAY  0.000

# Estimated pre-CTS on-chip clock insertion delay.
# Remove this estimate after CTS and use propagated clocks instead.
set PRECTS_CLOCK_LATENCY 1.500
set IDEAL_CLOCK_SLEW     0.200

# Pre-CTS uncertainty budget:
#   intra-clock = provisional source jitter/margin + 0.2 ns estimated CTS skew
#   cross-clock = 0.3 ns provisional relative PLL/board phase budget
#                 + 0.2 ns estimated CTS skew
set PRE_INTRA_SETUP_UNCERTAINTY 0.350
set PRE_INTRA_HOLD_UNCERTAINTY  0.300
set PRE_CROSS_SETUP_UNCERTAINTY 0.500
set PRE_CROSS_HOLD_UNCERTAINTY  0.500

# Both clocks enter through separate top-level ports.  They are intentionally
# defined as phase-related primary clocks.  Do NOT declare them asynchronous.
create_clock -name core_clock \
    -period $CORE_PERIOD \
    -waveform [list 0.000 [expr {$CORE_PERIOD / 2.0}]] \
    [get_ports cclk]

create_clock -name axi_clk \
    -period $AXI_PERIOD \
    -waveform [list 0.000 [expr {$AXI_PERIOD / 2.0}]] \
    [get_ports aclk]

# Explicit uncertainty for all launch/capture clock pairs.
set_clock_uncertainty -setup $PRE_INTRA_SETUP_UNCERTAINTY \
    -from [get_clocks core_clock] -to [get_clocks core_clock]
set_clock_uncertainty -hold $PRE_INTRA_HOLD_UNCERTAINTY \
    -from [get_clocks core_clock] -to [get_clocks core_clock]

set_clock_uncertainty -setup $PRE_INTRA_SETUP_UNCERTAINTY \
    -from [get_clocks axi_clk] -to [get_clocks axi_clk]
set_clock_uncertainty -hold $PRE_INTRA_HOLD_UNCERTAINTY \
    -from [get_clocks axi_clk] -to [get_clocks axi_clk]

set_clock_uncertainty -setup $PRE_CROSS_SETUP_UNCERTAINTY \
    -from [get_clocks axi_clk] -to [get_clocks core_clock]
set_clock_uncertainty -hold $PRE_CROSS_HOLD_UNCERTAINTY \
    -from [get_clocks axi_clk] -to [get_clocks core_clock]

set_clock_uncertainty -setup $PRE_CROSS_SETUP_UNCERTAINTY \
    -from [get_clocks core_clock] -to [get_clocks axi_clk]
set_clock_uncertainty -hold $PRE_CROSS_HOLD_UNCERTAINTY \
    -from [get_clocks core_clock] -to [get_clocks axi_clk]

# DC uses ideal clock networks.  CTS will be performed later in Innovus.
set_ideal_network       [get_pins {ipad_cclk/C ipad_aclk/C}]
set_dont_touch_network  [get_ports {cclk aclk}]
set_clock_transition $IDEAL_CLOCK_SLEW [all_clocks]
set_clock_latency    $PRECTS_CLOCK_LATENCY [all_clocks]

# Preserve the input-pad output nets so compile/ungroup cannot bypass the pads
# and reconnect functional sinks directly to the top-level clock/reset ports.
# These are synthesis-only constraints; do not copy them into CHIP_func.sdc.
set_dont_touch [get_nets {i_cclk i_aclk}]
set_dont_touch [get_nets {i_cresetn i_aresetn}]

# Belt-and-suspenders protection for the internal ideal clock networks rooted
# at the pad C pins.  The clocks are still created at the external cclk/aclk
# ports; this only preserves the intended clk -> PAD -> i_clk connectivity.
set_dont_touch_network [get_pins {ipad_cclk/C ipad_aclk/C}]

# Normal AXI data inputs exclude clocks and asynchronous resets.
set AXI_INPUTS [remove_from_collection \
    [all_inputs] \
    [get_ports {cclk aclk cresetn aresetn}]]
set AXI_OUTPUTS [all_outputs]

set_input_transition 0.500 $AXI_INPUTS
set_input_transition 0.500 [get_ports {cresetn aresetn}]

# Half-cycle system-level budget: external side 7.5 ns, CHIP side 7.5 ns.
set_input_delay  -max $AXI_IO_MAX_DELAY -clock [get_clocks axi_clk] $AXI_INPUTS
set_input_delay  -min $AXI_IO_MIN_DELAY -clock [get_clocks axi_clk] $AXI_INPUTS
set_output_delay -max $AXI_IO_MAX_DELAY -clock [get_clocks axi_clk] $AXI_OUTPUTS
set_output_delay -min $AXI_IO_MIN_DELAY -clock [get_clocks axi_clk] $AXI_OUTPUTS

set_load 40 $AXI_OUTPUTS

# External asynchronous-reset paths terminate only at the asynchronous reset
# pins of u_creset_sync and u_areset_sync.  Cutting paths from the ports is now
# structurally contained: the external reset ports no longer directly drive
# CORE state registers.
#
# Intentionally NOT false-pathed:
#   1. sync_ff1/Q -> sync_ff2/D (metastability-resolution path)
#   2. synchronizer srst_n -> CORE asynchronous reset pins
#      (recovery/removal checks must remain active)
set_false_path -from [get_ports cresetn]
set_false_path -from [get_ports aresetn]

# Keep the reset-synchronizer hierarchy identifiable for netlist inspection and
# physical placement.  The conditional form allows the SDC to be read even if
# hierarchy has already been transformed by another synthesis script.
set RESET_SYNC_INSTS [get_cells {u_creset_sync u_areset_sync}]

set_ungroup $RESET_SYNC_INSTS false
set_boundary_optimization $RESET_SYNC_INSTS false

set_ungroup [get_cells top] false
set_boundary_optimization [get_cells top] false

# Synthesis-only design-rule/physical-cell protection constraints.
set_max_fanout 20 $AXI_INPUTS

set_dont_touch [get_cells -hierarchical {ipad_* opad_*}]

# Post-compile sanity checks (run before handing the netlist to Innovus):
#   - Functional FFs must not be clocked directly by cclk/aclk.
#   - Their clock fanin must remain downstream of ipad_cclk/C or ipad_aclk/C.
#   - Check a full clock timing path if you want to confirm how DC is accounting
#     for the input-pad timing arc under this ideal-clock model.
