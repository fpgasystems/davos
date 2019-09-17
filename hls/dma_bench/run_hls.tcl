
open_project dma_bench_prj

set_top dma_bench

add_files dma_bench.hpp
add_files dma_bench.cpp


add_files -tb test_dma_bench.cpp

open_solution "solution1"
set_part {xc7vx690tffg1761-2}
create_clock -period 6.4 -name default

config_rtl -disable_start_propagation
csynth_design
export_design -format ip_catalog -display_name "DMA Bench" -description "" -vendor "ethz.systems.fpga" -version "0.1"

exit
