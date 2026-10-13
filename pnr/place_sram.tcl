set sram_inst [get_db insts top/line_buffer]

set margin_left 0.0
set margin_top  0.0

# Core boundary
set core_llx [get_db current_design .core_bbox.ll.x]
set core_lly [get_db current_design .core_bbox.ll.y]
set core_urx [get_db current_design .core_bbox.ur.x]
set core_ury [get_db current_design .core_bbox.ur.y]

# SRAM current bbox
set sram_llx [get_db $sram_inst .bbox.ll.x]
set sram_lly [get_db $sram_inst .bbox.ll.y]
set sram_urx [get_db $sram_inst .bbox.ur.x]
set sram_ury [get_db $sram_inst .bbox.ur.y]

# SRAM dimensions
set sram_width  [expr {$sram_urx - $sram_llx}]
set sram_height [expr {$sram_ury - $sram_lly}]

puts "SRAM width  = $sram_width"
puts "SRAM height = $sram_height"

# Upper-left placement
# location 使用 macro 左下角座標
set target_x [expr {$core_llx + $margin_left}]
set target_y [expr {$core_ury - $margin_top - $sram_height}]

puts "Target location = $target_x $target_y"

# 移動並固定
set_db $sram_inst .place_status placed
set_db $sram_inst .orient R0
set_db $sram_inst .location [list $target_x $target_y]
set_db $sram_inst .place_status fixed

puts "Final location = [get_db $sram_inst .location]"
puts "Final bbox     = [get_db $sram_inst .bbox]"