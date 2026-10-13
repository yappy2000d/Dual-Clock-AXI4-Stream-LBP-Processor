set_db cts_buffer_cells {CLKBUFX12 CLKBUFX8 CLKBUFX6 CLKBUFX4}
set_db cts_inverter_cells {CLKINVX12 CLKINVX8 CLKINVX6 CLKINVX4}
set_db cts_use_inverters true

set_db cts_target_max_transition_time_trunk 250ps
set_db cts_target_max_transition_time_leaf 200ps

set_db ccopt_auto_limit_insertion_delay_factor 1.05

create_route_rule -name cts_2w2s \
   -spacing_multiplier {METAL3:METAL5 2} \
   -width_multiplier {METAL3:METAL5 2} \
   -generate_via
create_route_rule -name cts_2s \
   -spacing_multiplier {METAL3:METAL5 2}

create_route_type -name cts_leaf \
    -top_preferred_layer    METAL3 \
    -bottom_preferred_layer METAL2 \
    -route_rule cts_2s
create_route_type -name cts_trunk \
    -top_preferred_layer    METAL5 \
    -bottom_preferred_layer METAL4 \
    -route_rule cts_2w2s
create_route_type -name cts_top \
    -top_preferred_layer    METAL5 \
    -bottom_preferred_layer METAL4 \
    -bottom_shield_layer METAL3 \
    -shield_net VSS \
    -route_rule cts_2w2s

set_db cts_route_type_top cts_top
set_db cts_route_type_trunk cts_trunk
set_db cts_route_type_leaf cts_leaf

set_db cts_top_fanout_threshold 1000