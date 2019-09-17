#open project
open_project dma_example_adm7v3/dma_example_adm7v3.xpr

update_compile_order -fileset sources_1


#start bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
