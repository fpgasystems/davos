#Bit stream generation
set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type1 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_MODE BPI16 [current_design]


##GT Ref clk differential pair for 10gig eth.  MGTREFCLK0P_116
create_clock -period 6.400 -name xgemac_clk_156 [get_ports xphy_refclk_p]
set_property PACKAGE_PIN T6 [get_ports xphy_refclk_p]

set_property PACKAGE_PIN U3 [get_ports xphy0_rxn]
set_property PACKAGE_PIN U4 [get_ports xphy0_rxp]
set_property PACKAGE_PIN T1 [get_ports xphy0_txn]
set_property PACKAGE_PIN T2 [get_ports xphy0_txp]

set_property PACKAGE_PIN R3 [get_ports xphy1_rxn]
set_property PACKAGE_PIN R4 [get_ports xphy1_rxp]
set_property PACKAGE_PIN P1 [get_ports xphy1_txn]
set_property PACKAGE_PIN P2 [get_ports xphy1_txp]


# SFP TX Disable for 10G PHY. Chip package 1157 on alpha data board only breaks out 2 transceivers!
set_property PACKAGE_PIN AC34 [get_ports {sfp_tx_disable[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sfp_tx_disable[0]}]
set_property PACKAGE_PIN AA34 [get_ports {sfp_tx_disable[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sfp_tx_disable[1]}]

set_property PACKAGE_PIN AA23 [get_ports sfp_on]
set_property IOSTANDARD LVCMOS18 [get_ports sfp_on]

set_property PACKAGE_PIN W30 [get_ports sfp_ready]
set_property IOSTANDARD LVCMOS18 [get_ports sfp_ready]

create_clock -period 6.400 -name clk156 [get_pins n10g_interface_inst/xgbaser_gt_wrapper_inst/clk156_bufg_inst/O]
create_clock -period 12.800 -name dclk [get_pins n10g_interface_inst/xgbaser_gt_wrapper_inst/dclk_bufg_inst/O]
create_clock -period 6.400 -name refclk [get_pins n10g_interface_inst/xgphy_refclk_ibuf/O]

set_clock_groups -name async_xgemac_drpclk -asynchronous -group [get_clocks -include_generated_clocks clk156] -group [get_clocks -include_generated_clocks dclk]

set_clock_groups -name async_ref_gmacTx -asynchronous -group [get_clocks clk156] -group [get_clocks n10g_interface_inst/network_inst_0/ten_gig_eth_pcs_pma_inst/inst/gt0_gtwizard_10gbaser_multi_gt_i/gt0_gtwizard_gth_10gbaser_i/gthe2_i/TXOUTCLK]

set_false_path -from [get_cells {n10g_interface_inst/xgbaser_gt_wrapper_inst/reset_pulse_reg[0]}]

#########################################################
# PCIe
#########################################################

set_property PACKAGE_PIN W27 [get_ports perst_n]
set_property IOSTANDARD LVCMOS18 [get_ports perst_n]
set_property PULLUP true [get_ports perst_n]
set_property PACKAGE_PIN F5 [get_ports pcie_clk_n]

#set_false_path -from [get_ports perst_n]



#set_property LOC GTHE2_CHANNEL_X1Y35 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y35 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN B5 [get_ports {pcie_rx_n[0]}]
set_property PACKAGE_PIN B6 [get_ports {pcie_rx_p[0]}]
set_property PACKAGE_PIN A3 [get_ports {pcie_tx_n[0]}]
set_property PACKAGE_PIN A4 [get_ports {pcie_tx_p[0]}]
#set_property LOC GTHE2_CHANNEL_X1Y34 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y34 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN D5 [get_ports {pcie_rx_n[1]}]
set_property PACKAGE_PIN D6 [get_ports {pcie_rx_p[1]}]
set_property PACKAGE_PIN B1 [get_ports {pcie_tx_n[1]}]
set_property PACKAGE_PIN B2 [get_ports {pcie_tx_p[1]}]
#set_property LOC GTHE2_CHANNEL_X1Y33 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y33 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN E3 [get_ports {pcie_rx_n[2]}]
set_property PACKAGE_PIN E4 [get_ports {pcie_rx_p[2]}]
set_property PACKAGE_PIN C3 [get_ports {pcie_tx_n[2]}]
set_property PACKAGE_PIN C4 [get_ports {pcie_tx_p[2]}]
#set_property LOC GTHE2_CHANNEL_X1Y32 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y32 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN G3 [get_ports {pcie_rx_n[3]}]
set_property PACKAGE_PIN G4 [get_ports {pcie_rx_p[3]}]
set_property PACKAGE_PIN D1 [get_ports {pcie_tx_n[3]}]
set_property PACKAGE_PIN D2 [get_ports {pcie_tx_p[3]}]
#set_property LOC GTHE2_CHANNEL_X1Y31 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[4].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y31 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[4].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN J3 [get_ports {pcie_rx_n[4]}]
set_property PACKAGE_PIN J4 [get_ports {pcie_rx_p[4]}]
set_property PACKAGE_PIN F1 [get_ports {pcie_tx_n[4]}]
set_property PACKAGE_PIN F2 [get_ports {pcie_tx_p[4]}]
#set_property LOC GTHE2_CHANNEL_X1Y30 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[5].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y30 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[5].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN K5 [get_ports {pcie_rx_n[5]}]
set_property PACKAGE_PIN K6 [get_ports {pcie_rx_p[5]}]
set_property PACKAGE_PIN H1 [get_ports {pcie_tx_n[5]}]
set_property PACKAGE_PIN H2 [get_ports {pcie_tx_p[5]}]
#set_property LOC GTHE2_CHANNEL_X1Y29 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[6].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y29 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[6].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN L3 [get_ports {pcie_rx_n[6]}]
set_property PACKAGE_PIN L4 [get_ports {pcie_rx_p[6]}]
set_property PACKAGE_PIN K1 [get_ports {pcie_tx_n[6]}]
set_property PACKAGE_PIN K2 [get_ports {pcie_tx_p[6]}]
#set_property LOC GTHE2_CHANNEL_X1Y28 [get_cells {dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[7].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property LOC GTHE2_CHANNEL_X1Y28 [get_cells {dma_driver_inst/dma_inst/inst/pcie3_ip_i/inst/gt_top_i/pipe_wrapper_i/pipe_lane[7].gt_wrapper_i/gth_channel.gthe2_channel_i}]
set_property PACKAGE_PIN N3 [get_ports {pcie_rx_n[7]}]
set_property PACKAGE_PIN N4 [get_ports {pcie_rx_p[7]}]
set_property PACKAGE_PIN M1 [get_ports {pcie_tx_n[7]}]
set_property PACKAGE_PIN M2 [get_ports {pcie_tx_p[7]}]




#########################################################
# LEDS
#########################################################

#clock
#set_property PACKAGE_PIN [get_ports {clk_ref_p}]
#set_property PACKAGE_PIN [get_ports {clk_ref_n}]

set_property PACKAGE_PIN AH15 [get_ports c0_sys_clk_p]
set_property PACKAGE_PIN AJ15 [get_ports c0_sys_clk_n]
set_property PACKAGE_PIN G30 [get_ports c1_sys_clk_p]
set_property PACKAGE_PIN G31 [get_ports c1_sys_clk_n]


#on & poke
set_property PACKAGE_PIN AA24 [get_ports {dram_on[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dram_on[*]}]
set_property PACKAGE_PIN AB25 [get_ports {dram_on[1]}]
set_property PACKAGE_PIN AA31 [get_ports pok_dram]
set_property IOSTANDARD LVCMOS18 [get_ports pok_dram]


set_property PACKAGE_PIN AH10 [get_ports {c0_ddr3_dm[0]}]
set_property PACKAGE_PIN AF9 [get_ports {c0_ddr3_dm[1]}]
set_property PACKAGE_PIN AM13 [get_ports {c0_ddr3_dm[2]}]
set_property PACKAGE_PIN AL10 [get_ports {c0_ddr3_dm[3]}]
set_property PACKAGE_PIN AL20 [get_ports {c0_ddr3_dm[4]}]
set_property PACKAGE_PIN AJ24 [get_ports {c0_ddr3_dm[5]}]
set_property PACKAGE_PIN AD22 [get_ports {c0_ddr3_dm[6]}]
set_property PACKAGE_PIN AD15 [get_ports {c0_ddr3_dm[7]}]
set_property PACKAGE_PIN AM23 [get_ports {c0_ddr3_dm[8]}]

set_property VCCAUX_IO NORMAL [get_ports {c0_ddr3_dm[*]}]
set_property SLEW FAST [get_ports {c0_ddr3_dm[*]}]
set_property IOSTANDARD SSTL15 [get_ports {c0_ddr3_dm[*]}]


set_property PACKAGE_PIN B32 [get_ports {c1_ddr3_dm[0]}]
set_property PACKAGE_PIN A30 [get_ports {c1_ddr3_dm[1]}]
set_property PACKAGE_PIN E24 [get_ports {c1_ddr3_dm[2]}]
set_property PACKAGE_PIN B26 [get_ports {c1_ddr3_dm[3]}]
set_property PACKAGE_PIN U31 [get_ports {c1_ddr3_dm[4]}]
set_property PACKAGE_PIN R29 [get_ports {c1_ddr3_dm[5]}]
set_property PACKAGE_PIN K34 [get_ports {c1_ddr3_dm[6]}]
set_property PACKAGE_PIN N34 [get_ports {c1_ddr3_dm[7]}]
set_property PACKAGE_PIN P25 [get_ports {c1_ddr3_dm[8]}]

set_property VCCAUX_IO NORMAL [get_ports {c1_ddr3_dm[*]}]
set_property SLEW FAST [get_ports {c1_ddr3_dm[*]}]
set_property IOSTANDARD SSTL15 [get_ports {c1_ddr3_dm[*]}]


#########################################################
# LEDS
#########################################################

set_property IOSTANDARD LVCMOS18 [get_ports {led[*]}]
set_property PACKAGE_PIN AC33 [get_ports {led[0]}]
set_property PACKAGE_PIN V32 [get_ports {led[1]}]
set_property PACKAGE_PIN V33 [get_ports {led[2]}]
set_property PACKAGE_PIN AB31 [get_ports {led[3]}]
set_property PACKAGE_PIN AB32 [get_ports {led[4]}]
set_property PACKAGE_PIN U30 [get_ports {led[5]}]

set_property IOSTANDARD LVCMOS18 [get_ports usr_sw]
set_property PACKAGE_PIN AB30 [get_ports usr_sw]
#create_clock -name sys_clk233 -period 4.288 [get_ports sys_clk_p]

#set_property VCCAUX_IO DONTCARE [get_ports {sys_clk_p}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {sys_clk_p}]
#set_property LOC AY18 [get_ports {sys_clk_p}]

## Bank: 32 - Byte
#set_property VCCAUX_IO DONTCARE [get_ports {sys_clk_n}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {sys_clk_n}]
#set_property LOC AY17 [get_ports {sys_clk_n}]

#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk233]


#using c0/1_init_calib_complete as input
set_clock_groups -name clk156_pll_i -asynchronous -group [get_clocks clk_pll_i] -group [get_clocks clk156]
set_clock_groups -name clk156_pll_i_1 -asynchronous -group [get_clocks clk_pll_i_1] -group [get_clocks clk156]
#
#set_clock_groups -name async_ref_sys_clk -asynchronous #    -group [get_clocks  sys_clk233] #    -group [get_clocks  mcb_clk_ref]
#
#set_false_path -from [get_cells rst_n_r3_reg__0]
#
#set_false_path -from [get_cells n10g_interface_inst/xgbaser_gt_wrapper_inst/reset_pulse_reg[0]]


##set_false_path -from [get_cells n10g_interface_inst/xgbaser_gt_wrapper_inst/core_reset_reg]


#set_false_path -from [get_cells reset156_25_n_r3_reg]
#set_false_path -to [get_cells part_resetn_syncD2_reg]

#set_multicycle_path -setup -from [get_cells network_stack_inst/aresetn_reg_reg] 8
#set_multicycle_path -hold -from [get_cells network_stack_inst/aresetn_reg_reg] 8


