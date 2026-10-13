read_io_file CHIP.io
create_floorplan -site tsm3site -core_density_size 1 0.6 50 50 50 50
delete_relative_floorplan -all
source place_sram.tcl
source add_io_fillers.tcl
create_route_halo -all_blocks -space 1.5 -bottom_layer METAL1 -top_layer METAL5
create_place_halo -all_blocks -halo_deltas {1 1 1 1}

# foreach cell [get_db [get_db insts -if {.base_cell.base_class == block}] .name] {
#     set llx [get_db inst:$cell .bbox.ll.x]
#     set lly [get_db inst:$cell .bbox.ll.y]
#     set urx [get_db inst:$cell .bbox.ur.x]
#     set ury [get_db inst:$cell .bbox.ur.y]
#     create_route_blockage -name RBKM45 -pg_nets -layers {METAL4 METAL5} -rects [list [expr $llx-0.46] [expr $lly-0.46] [expr $urx+0.46] [expr $ury+0.46]]
#     create_route_blockage -name RBKM45 -pg_nets -layers {METAL4 METAL5} -rects [list $urx [expr $lly-0.46] [expr $urx+0.46] [expr $ury+0.46]]
#     create_route_blockage -name RBKM45 -pg_nets -layers {METAL4 METAL5} -rects [list [expr $llx-0.46] $lly $llx $ury]
#     create_route_blockage -name RBKM45 -pg_nets -layers {METAL4 METAL5} -rects [list $urx $lly [expr $urx+0.46] $ury]
# }

set_db finish_floorplan_active_objs {core macro macro_halo soft_blockage}
finish_floorplan -fill_place_blockage soft 20.0

write_def -floorplan -netlist CHIP.def
perl addbonding_v3.8.pl -stylus CHIP.def
source addRouteBlk.cmd

write_floorplan CHIP.fp