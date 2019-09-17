#Network
create_ip -name ten_gig_eth_pcs_pma -vendor xilinx.com -library ip -version 6.0 -module_name ten_gig_eth_pcs_pma_ip -dir $device_ip_dir
set_property -dict [list CONFIG.MDIO_Management {false} CONFIG.base_kr {BASE-R} CONFIG.baser32 {64bit}] [get_ips ten_gig_eth_pcs_pma_ip]
generate_target {instantiation_template} [get_files $device_ip_dir/ten_gig_eth_pcs_pma_ip/ten_gig_eth_pcs_pma_ip.xci]
update_compile_order -fileset sources_1

create_ip -name ten_gig_eth_mac -vendor xilinx.com -library ip -version 15.1 -module_name ten_gig_eth_mac_ip -dir $device_ip_dir
set_property -dict [list CONFIG.Management_Interface {false} CONFIG.Statistics_Gathering {false}] [get_ips ten_gig_eth_mac_ip]
generate_target {instantiation_template} [get_files $device_ip_dir/ten_gig_eth_mac_ip/ten_gig_eth_mac_ip.xci]
update_compile_order -fileset sources_1

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name axis_sync_fifo -dir $device_ip_dir
set_property -dict [list CONFIG.INTERFACE_TYPE {AXI_STREAM} CONFIG.TDATA_NUM_BYTES {8} CONFIG.TUSER_WIDTH {0} CONFIG.Enable_TLAST {true} CONFIG.HAS_TKEEP {true} CONFIG.Enable_Data_Counts_axis {true} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Full_Flags_Reset_Value {1} CONFIG.TSTRB_WIDTH {8} CONFIG.TKEEP_WIDTH {8} CONFIG.FIFO_Implementation_wach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wach {15} CONFIG.Empty_Threshold_Assert_Value_wach {14} CONFIG.FIFO_Implementation_wrch {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wrch {15} CONFIG.Empty_Threshold_Assert_Value_wrch {14} CONFIG.FIFO_Implementation_rach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_rach {15} CONFIG.Empty_Threshold_Assert_Value_rach {14}] [get_ips axis_sync_fifo]
generate_target {instantiation_template} [get_files $device_ip_dir/ff1157/axis_sync_fifo/axis_sync_fifo.xci]
update_compile_order -fileset sources_1

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name cmd_fifo_xgemac_rxif -dir $device_ip_dir
set_property -dict [list CONFIG.Component_Name {cmd_fifo_xgemac_rxif} CONFIG.Input_Data_Width {16} CONFIG.Output_Data_Width {16} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Full_Flags_Reset_Value {1} CONFIG.Enable_Safety_Circuit {true}] [get_ips cmd_fifo_xgemac_rxif]
generate_target {instantiation_template} [get_files $device_ip_dir/cmd_fifo_xgemac_rxif/cmd_fifo_xgemac_rxif.xci]
update_compile_order -fileset sources_1


create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name cmd_fifo_xgemac_txif -dir $device_ip_dir
set_property -dict [list CONFIG.Input_Data_Width {1} CONFIG.Output_Data_Width {1} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Full_Flags_Reset_Value {1}] [get_ips cmd_fifo_xgemac_txif]
generate_target {instantiation_template} [get_files $device_ip_dir/ff1157/cmd_fifo_xgemac_txif/cmd_fifo_xgemac_txif.xci]
update_compile_order -fileset sources_1
