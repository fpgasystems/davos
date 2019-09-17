
open_project mem_read_cmd_merger_512_prj

set_top mem_read_cmd_merger_512

add_files ../partition.hpp
add_files mem_read_cmd_merger_512.hpp
add_files mem_read_cmd_merger_512.cpp


#add_files -tb test_mem_read_cmd_merger_512.cpp

open_solution "solution1"
set_part {xc7vx690tffg1761-2}
create_clock -period 6.4 -name default

csynth_design
export_design -format ip_catalog -display_name "Read cmd merger (512bit)" -description "" -vendor "ethz.systems.fpga" -version "0.1"

exit
