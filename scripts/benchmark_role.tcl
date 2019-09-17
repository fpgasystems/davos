#Role IPs


create_ip -name dma_bench -vendor ethz.systems.fpga -library hls -version 0.1 -module_name dma_bench_ip -dir $device_ip_dir
generate_target {instantiation_template} [get_files $device_ip_dir/dma_bench_ip/dma_bench_ip.xci]
update_compile_order -fileset sources_1

#VIOs

create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_iperf -dir $ip_dir
set_property -dict [list CONFIG.C_NUM_PROBE_OUT {2} CONFIG.C_EN_PROBE_IN_ACTIVITY {0} CONFIG.C_NUM_PROBE_IN {0} CONFIG.Component_Name {vio_iperf}] [get_ips vio_iperf]
generate_target {instantiation_template} [get_files $ip_dir/vio_iperf/vio_iperf.xci]

create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_udp_iperf_client -dir $ip_dir
set_property -dict [list CONFIG.C_EN_PROBE_IN_ACTIVITY {0} CONFIG.C_NUM_PROBE_IN {0} CONFIG.Component_Name {vio_udp_iperf_client}] [get_ips vio_udp_iperf_client]
generate_target {instantiation_template} [get_files $ip_dir/vio_udp_iperf_client/vio_udp_iperf_client.xci]
