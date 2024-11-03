set_part xc7a35tcpg236-1
add_files [ exec find src -name *.v ]
add_files src/Basys-3-Master.xdc
set_property INCLUDE_DIRS src [current_fileset]
set_property top riscv_top [current_fileset]
synth_design
opt_design
place_design
phys_opt_design
route_design
write_bitstream gen.bit
