
#DDR
add_files $davos_root_dir/ip/mig_7series_0.dcp
add_files $davos_root_dir/ip/mig_axi_mm_dual.dcp

create_ip -name axi_datamover -vendor xilinx.com -library ip -version 5.1 -module_name axi_datamover_mem -dir $device_ip_dir
set_property -dict [list CONFIG.Component_Name {axi_datamover_mem} CONFIG.c_mm2s_stscmd_is_async {true} CONFIG.c_m_axi_mm2s_data_width {512} CONFIG.c_m_axis_mm2s_tdata_width {512} CONFIG.c_mm2s_burst_size {8} CONFIG.c_mm2s_btt_used {23} CONFIG.c_s2mm_stscmd_is_async {true} CONFIG.c_m_axi_s2mm_data_width {512} CONFIG.c_s_axis_s2mm_tdata_width {512} CONFIG.c_s2mm_burst_size {8} CONFIG.c_s2mm_btt_used {23} CONFIG.c_s2mm_include_sf {false} CONFIG.c_m_axi_mm2s_id_width {1} CONFIG.c_m_axi_s2mm_id_width {1}] [get_ips axi_datamover_mem]
generate_target {instantiation_template} [get_files $device_ip_dir/axi_datamover_mem/axi_datamover_mem.xci]
update_compile_order -fileset sources_1

create_ip -name axi_datamover -vendor xilinx.com -library ip -version 5.1 -module_name axi_datamover_mem_unaligned -dir $device_ip_dir
set_property -dict [list CONFIG.Component_Name {axi_datamover_mem_unaligned} CONFIG.c_mm2s_stscmd_is_async {true} CONFIG.c_m_axi_mm2s_data_width {512} CONFIG.c_m_axis_mm2s_tdata_width {512} CONFIG.c_include_mm2s_dre {true} CONFIG.c_mm2s_burst_size {8} CONFIG.c_mm2s_btt_used {23} CONFIG.c_s2mm_stscmd_is_async {true} CONFIG.c_m_axi_s2mm_data_width {512} CONFIG.c_s_axis_s2mm_tdata_width {512} CONFIG.c_include_s2mm_dre {true} CONFIG.c_s2mm_burst_size {8} CONFIG.c_s2mm_btt_used {23} CONFIG.c_s2mm_include_sf {false} CONFIG.c_m_axi_mm2s_id_width {1} CONFIG.c_m_axi_s2mm_id_width {1}] [get_ips axi_datamover_mem_unaligned]
generate_target {instantiation_template} [get_files $device_ip_dir/axi_datamover_mem_unaligned/axi_datamover_mem_unaligned.xci]
update_compile_order -fileset sources_1

