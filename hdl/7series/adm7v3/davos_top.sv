/*
 * Copyright (c) 2019, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its contributors
 * may be used to endorse or promote products derived from this software
 * without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
`timescale 1ns / 1ps
`default_nettype none

`include "davos_config.svh"
`include "davos_types.svh"

module davos_top
(
    // 156.25 MHz clock in
    input wire                           xphy_refclk_p,
    input wire                           xphy_refclk_n,
    // Ethernet Tx & Rx Differential Pairs //  
    output wire                          xphy0_txp,
    output wire                          xphy0_txn,
    input wire                           xphy0_rxp,
    input wire                           xphy0_rxn,
    output wire                          xphy1_txp,
    output wire                          xphy1_txn,
    input wire                           xphy1_rxp,
    input wire                           xphy1_rxn,
    
    output wire[1:0]                     sfp_tx_disable,
    output wire                          sfp_on,
    input  wire                          sfp_ready, //used as reset to sfp
    
    // PCI Express slot PERST# reset signal
    input wire                           perst_n, //TODO rename pcie_rstn
    // PCIe differential reference clock input
    input wire                           pcie_clk_p,
    input wire                           pcie_clk_n,
    // PCIe differential transmit output
    output wire  [7:0]                   pcie_tx_p,
    output wire  [7:0]                   pcie_tx_n,
    // PCIe differential receive output
    input wire   [7:0]                   pcie_rx_p,
    input wire   [7:0]                   pcie_rx_n,
    
`ifdef USE_DDR    
    // Connection to SODIMM-A
    // Inouts
    inout wire [71:0]                    c0_ddr3_dq,
    inout wire [8:0]                     c0_ddr3_dqs_n,
    inout wire [8:0]                     c0_ddr3_dqs_p,
    output wire [15:0]                   c0_ddr3_addr,
    output wire [2:0]                    c0_ddr3_ba,
    output wire                          c0_ddr3_ras_n,
    output wire                          c0_ddr3_cas_n,
    output wire                          c0_ddr3_we_n,
    output wire                          c0_ddr3_reset_n,
    output wire [1:0]                    c0_ddr3_ck_p,
    output wire [1:0]                    c0_ddr3_ck_n,
    output wire [1:0]                    c0_ddr3_cke,
    output wire [1:0]                    c0_ddr3_cs_n,
    output wire [1:0]                    c0_ddr3_odt,
    // Differential system clocks
    input wire                           c0_sys_clk_p,
    input wire                           c0_sys_clk_n,
    // differential iodelayctrl clk (reference clock)
    input wire                           clk_ref_p,
    input wire                           clk_ref_n,
    // Inouts
    inout wire [71:0]                    c1_ddr3_dq,
    inout wire [8:0]                     c1_ddr3_dqs_n,
    inout wire [8:0]                     c1_ddr3_dqs_p,
    output wire [15:0]                   c1_ddr3_addr,
    output wire [2:0]                    c1_ddr3_ba,
    output wire                          c1_ddr3_ras_n,
    output wire                          c1_ddr3_cas_n,
    output wire                          c1_ddr3_we_n,
    output wire                          c1_ddr3_reset_n,
    output wire [1:0]                    c1_ddr3_ck_p,
    output wire [1:0]                    c1_ddr3_ck_n,
    output wire [1:0]                    c1_ddr3_cke,
    output wire [1:0]                    c1_ddr3_cs_n,
    output wire [1:0]                    c1_ddr3_odt,
    // Differential system clocks
    input wire                           c1_sys_clk_p,
    input wire                           c1_sys_clk_n,             
    input wire                           pok_dram, //used as reset to ddr
    output wire[8:0]                     c0_ddr3_dm,
    output wire[8:0]                     c1_ddr3_dm,
    output wire[1:0]                     dram_on,
`endif
    input wire                           usr_sw,
    output wire[5:0]                     led
);


/*
 * Clock & Reset Signals
 */
wire clk_ref_200;

wire user_clk;
wire user_aresetn;

/*
 * PCIe Signals
 */
wire pcie_lnk_up;
wire pcie_ref_clk;

// PCIe user clock & reset
wire pcie_clk;
wire pcie_aresetn;

/*
 * DMA Signals
 */
//Axi Lite Control Bus
axi_lite        axil_control();
axi_mm          axim_control();

wire        c2h_dsc_byp_load_0;
wire        c2h_dsc_byp_ready_0;
wire[63:0]  c2h_dsc_byp_addr_0;
wire[31:0]  c2h_dsc_byp_len_0;

wire        h2c_dsc_byp_load_0;
wire        h2c_dsc_byp_ready_0;
wire[63:0]  h2c_dsc_byp_addr_0;
wire[31:0]  h2c_dsc_byp_len_0;

axi_stream  axis_dma_c2h();
axi_stream  axis_dma_h2c();

wire[7:0] c2h_sts_0;
wire[7:0] h2c_sts_0;

/*
 * Network Signals
 */
assign sfp_on = 1'b1;
wire network_init;

wire net_clk;
(* max_fanout = "64" *)  reg net_aresetn;
reg reset156_25_n_r1, reset156_25_n_r2, reset156_25_n_r3;
always @(posedge net_clk) begin
    reset156_25_n_r1 <= perst_n & pok_dram & network_init;
    reset156_25_n_r2 <= reset156_25_n_r1;
    net_aresetn <= reset156_25_n_r2;
end

axi_stream #(.WIDTH(64))    axis_net_rx_data[NUM_NET_PORTS]();
axi_stream #(.WIDTH(64))    axis_net_tx_data[NUM_NET_PORTS]();


/*
 * DDR Signals
 */
localparam DDR_CHANNEL0 = 0;
localparam DDR_CHANNEL1 = 1;
localparam NUM_DDR_CHANNELS = 2;//TODO Move

`ifdef USE_DDR
assign dram_on = 2'b11;
assign c0_ddr3_dm = 9'h0;
assign c1_ddr3_dm = 9'h0;
`else
wire pok_dram;
assign pok_dram = 1'b1;
`endif


logic[NUM_DDR_CHANNELS-1:0] ddr_init_calib_complete [2:0];
wire ddr_calib_complete;

//registers for crossing clock domains (from DDR clock to User Clock)
always @(posedge user_clk)
    if (~user_aresetn) begin
        ddr_init_calib_complete[1] <= '0;
        ddr_init_calib_complete[2] <= '0;
    end
    else begin
        ddr_init_calib_complete[1] <= ddr_init_calib_complete[0];
        ddr_init_calib_complete[2] <= ddr_init_calib_complete[1];
    end

assign ddr_calib_complete = &ddr_init_calib_complete[2];

/*
 * Clock Generation
 */
wire GND_1;

GND GND(.G(GND_1));
       
       
       IBUFDS_GTE2 #(
            .CLKCM_CFG("TRUE"),   // Refer to Transceiver User Guide
            .CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
            .CLKSWING_CFG(2'b11)  // Refer to Transceiver User Guide
         )
         IBUFDS_GTE2_inst (
            .O(pcie_ref_clk),         // 1-bit output: Refer to Transceiver User Guide
            .ODIV2(),            // 1-bit output: Refer to Transceiver User Guide
            .CEB(GND_1),          // 1-bit input: Refer to Transceiver User Guide
            .I(pcie_clk_p),        // 1-bit input: Refer to Transceiver User Guide
            .IB(pcie_clk_n)        // 1-bit input: Refer to Transceiver User Guide
);


/*
 * LEDs
 */
localparam  LED_CTR_WIDTH           = 26;
logic [LED_CTR_WIDTH-1:0]           led_pcie_clk;
logic [LED_CTR_WIDTH-1:0]           led_net_clk;
logic [LED_CTR_WIDTH-1:0]           led_ddr_clk;

always @(posedge pcie_clk)
begin
    led_pcie_clk <= led_pcie_clk + {{(LED_CTR_WIDTH-1){1'b0}}, 1'b1};
end

always @(posedge net_clk)
begin
    led_net_clk <= led_net_clk + {{(LED_CTR_WIDTH-1){1'b0}}, 1'b1};
end

`ifdef USE_DDR
always @(posedge mem_clk[DDR_CHANNEL0])
begin
    led_ddr_clk <= led_ddr_clk + {{(LED_CTR_WIDTH-1){1'b0}}, 1'b1};
end
`endif

assign led[0] = pcie_lnk_up;
assign led[1] = network_init;
assign led[2] = ddr_calib_complete;
assign led[3] = led_pcie_clk[LED_CTR_WIDTH-1];
assign led[4] = led_net_clk[LED_CTR_WIDTH-1];
assign led[5] = led_ddr_clk[LED_CTR_WIDTH-1];


/*
 * 10G Network Interface Module
 */
adm7v3_10g_interface n10g_interface_inst (
.reset(~perst_n | ~sfp_ready),
.aresetn(net_aresetn),
.xphy_refclk_p(xphy_refclk_p),
.xphy_refclk_n(xphy_refclk_n),
.xphy0_txp(xphy0_txp),
.xphy0_txn(xphy0_txn),
.xphy0_rxp(xphy0_rxp),
.xphy0_rxn(xphy0_rxn),
.xphy1_txp(xphy1_txp),
.xphy1_txn(xphy1_txn),
.xphy1_rxp(xphy1_rxp),
.xphy1_rxn(xphy1_rxn),

.m_axis_net_rx(axis_net_rx_data),
.s_axis_net_tx(axis_net_tx_data),

.sfp_tx_disable(sfp_tx_disable),
.clk156_out(net_clk),
.clk_ref_200_out(clk_ref_200),
.network_reset_done(network_init),
.led()
);


/*
 * Memory Interface
 */
localparam C0_C_S_AXI_ID_WIDTH = 1;
localparam C0_C_S_AXI_ADDR_WIDTH = 32;
localparam C0_C_S_AXI_DATA_WIDTH = 512;

wire[NUM_DDR_CHANNELS-1:0] mem_clk;
wire[NUM_DDR_CHANNELS-1:0] mem_aresetn;

// Slave Interface Write Address Ports
wire [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_awid   [NUM_DDR_CHANNELS-1:0];
wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s_axi_awaddr [NUM_DDR_CHANNELS-1:0];
wire [7:0]                              s_axi_awlen  [NUM_DDR_CHANNELS-1:0];
wire [2:0]                              s_axi_awsize [NUM_DDR_CHANNELS-1:0];
wire [1:0]                              s_axi_awburst    [NUM_DDR_CHANNELS-1:0];
wire [0:0]                              s_axi_awlock [NUM_DDR_CHANNELS-1:0];
wire [3:0]                              s_axi_awcache    [NUM_DDR_CHANNELS-1:0];
wire [2:0]                              s_axi_awprot [NUM_DDR_CHANNELS-1:0];
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_awvalid;
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_awready;
 // Slave Interface Write Data Ports
wire [C0_C_S_AXI_DATA_WIDTH-1:0]        s_axi_wdata  [NUM_DDR_CHANNELS-1:0];
wire [(C0_C_S_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb  [NUM_DDR_CHANNELS-1:0];
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_wlast;
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_wvalid;
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_wready;
 // Slave Interface Write Response Ports
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_bready;
wire [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_bid    [NUM_DDR_CHANNELS-1:0];
wire [1:0]                              s_axi_bresp  [NUM_DDR_CHANNELS-1:0];
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_bvalid;
 // Slave Interface Read Address Ports
wire [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_arid   [NUM_DDR_CHANNELS-1:0];
wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s_axi_araddr [NUM_DDR_CHANNELS-1:0];
wire [7:0]                              s_axi_arlen  [NUM_DDR_CHANNELS-1:0];
wire [2:0]                              s_axi_arsize [NUM_DDR_CHANNELS-1:0];
wire [1:0]                              s_axi_arburst    [NUM_DDR_CHANNELS-1:0];
wire [0:0]                              s_axi_arlock [NUM_DDR_CHANNELS-1:0];
wire [3:0]                              s_axi_arcache    [NUM_DDR_CHANNELS-1:0];
wire [2:0]                              s_axi_arprot [NUM_DDR_CHANNELS-1:0];
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_arvalid;
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_arready;
 // Slave Interface Read Data Ports
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_rready;
wire [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_rid    [NUM_DDR_CHANNELS-1:0];
wire [C0_C_S_AXI_DATA_WIDTH-1:0]        s_axi_rdata  [NUM_DDR_CHANNELS-1:0];
wire [1:0]                              s_axi_rresp  [NUM_DDR_CHANNELS-1:0];
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_rlast;
wire[NUM_DDR_CHANNELS-1:0]                                    s_axi_rvalid;

`ifdef USE_DDR
mem_driver  mem_driver_inst(
.sys_rst(perst_n & pok_dram),

/* I/O INTERFACE */
// differential iodelayctrl clk (reference clock)
.clk_ref_p(clk_ref_p),
.clk_ref_n(clk_ref_n),
//SODIMM 0
// Inouts
.c0_ddr3_dq(c0_ddr3_dq),
.c0_ddr3_dqs_n(c0_ddr3_dqs_n),
.c0_ddr3_dqs_p(c0_ddr3_dqs_p),
// Outputs
.c0_ddr3_addr(c0_ddr3_addr),
.c0_ddr3_ba(c0_ddr3_ba),
.c0_ddr3_ras_n(c0_ddr3_ras_n),
.c0_ddr3_cas_n(c0_ddr3_cas_n),
.c0_ddr3_we_n(c0_ddr3_we_n),
.c0_ddr3_reset_n(c0_ddr3_reset_n),
.c0_ddr3_ck_p(c0_ddr3_ck_p),
.c0_ddr3_ck_n(c0_ddr3_ck_n),
.c0_ddr3_cke(c0_ddr3_cke),
.c0_ddr3_cs_n(c0_ddr3_cs_n),
//.c0_ddr3_dm(c0_ddr3_dm),
.c0_ddr3_odt(c0_ddr3_odt),
//.c0_ui_clk(c0_ui_clk),
.c0_init_calib_complete(ddr_init_calib_complete[0][DDR_CHANNEL0]),
  // Differential system clocks
.c0_sys_clk_p(c0_sys_clk_p),
.c0_sys_clk_n(c0_sys_clk_n),

//SODIMM 1
// Inouts
.c1_ddr3_dq(c1_ddr3_dq),
.c1_ddr3_dqs_n(c1_ddr3_dqs_n),
.c1_ddr3_dqs_p(c1_ddr3_dqs_p),
// Outputs
.c1_ddr3_addr(c1_ddr3_addr),
.c1_ddr3_ba(c1_ddr3_ba),
.c1_ddr3_ras_n(c1_ddr3_ras_n),
.c1_ddr3_cas_n(c1_ddr3_cas_n),
.c1_ddr3_we_n(c1_ddr3_we_n),
.c1_ddr3_reset_n(c1_ddr3_reset_n),
.c1_ddr3_ck_p(c1_ddr3_ck_p),
.c1_ddr3_ck_n(c1_ddr3_ck_n),
.c1_ddr3_cke(c1_ddr3_cke),
.c1_ddr3_cs_n(c1_ddr3_cs_n),
//.c1_ddr3_dm(c1_ddr3_dm),
.c1_ddr3_odt(c1_ddr3_odt),
//.c1_ui_clk(c1_ui_clk),
.c1_init_calib_complete(ddr_init_calib_complete[0][DDR_CHANNEL1]),
  // Differential system clocks
.c1_sys_clk_p(c1_sys_clk_p),
.c1_sys_clk_n(c1_sys_clk_n),


/* OS INTERFACE */
.mem0_clk(mem_clk[DDR_CHANNEL0]),
.mem0_aresetn(mem_aresetn[DDR_CHANNEL0]),

.s0_axi_awid(s_axi_awid[DDR_CHANNEL0]),
.s0_axi_awaddr(s_axi_awaddr[DDR_CHANNEL0]),
.s0_axi_awlen(s_axi_awlen[DDR_CHANNEL0]),
.s0_axi_awsize(s_axi_awsize[DDR_CHANNEL0]),
.s0_axi_awburst(s_axi_awburst[DDR_CHANNEL0]),
.s0_axi_awlock(s_axi_awlock[DDR_CHANNEL0]),
.s0_axi_awcache(s_axi_awcache[DDR_CHANNEL0]),
.s0_axi_awprot(s_axi_awprot[DDR_CHANNEL0]),
.s0_axi_awvalid(s_axi_awvalid[DDR_CHANNEL0]),
.s0_axi_awready(s_axi_awready[DDR_CHANNEL0]),

.s0_axi_wdata(s_axi_wdata[DDR_CHANNEL0]),
.s0_axi_wstrb(s_axi_wstrb[DDR_CHANNEL0]),
.s0_axi_wlast(s_axi_wlast[DDR_CHANNEL0]),
.s0_axi_wvalid(s_axi_wvalid[DDR_CHANNEL0]),
.s0_axi_wready(s_axi_wready[DDR_CHANNEL0]),

.s0_axi_bready(s_axi_bready[DDR_CHANNEL0]),
.s0_axi_bid(s_axi_bid[DDR_CHANNEL0]),
.s0_axi_bresp(s_axi_bresp[DDR_CHANNEL0]),
.s0_axi_bvalid(s_axi_bvalid[DDR_CHANNEL0]),

.s0_axi_arid(s_axi_arid[DDR_CHANNEL0]),
.s0_axi_araddr(s_axi_araddr[DDR_CHANNEL0]),
.s0_axi_arlen(s_axi_arlen[DDR_CHANNEL0]),
.s0_axi_arsize(s_axi_arsize[DDR_CHANNEL0]),
.s0_axi_arburst(s_axi_arburst[DDR_CHANNEL0]),
.s0_axi_arlock(s_axi_arlock[DDR_CHANNEL0]),
.s0_axi_arcache(s_axi_arcache[DDR_CHANNEL0]),
.s0_axi_arprot(s_axi_arprot[DDR_CHANNEL0]),
.s0_axi_arvalid(s_axi_arvalid[DDR_CHANNEL0]),
.s0_axi_arready(s_axi_arready[DDR_CHANNEL0]),

.s0_axi_rready(s_axi_rready[DDR_CHANNEL0]),
.s0_axi_rid(s_axi_rid[DDR_CHANNEL0]),
.s0_axi_rdata(s_axi_rdata[DDR_CHANNEL0]),
.s0_axi_rresp(s_axi_rresp[DDR_CHANNEL0]),
.s0_axi_rlast(s_axi_rlast[DDR_CHANNEL0]),
.s0_axi_rvalid(s_axi_rvalid[DDR_CHANNEL0]),

.mem1_clk(mem_clk[DDR_CHANNEL1]),
.mem1_aresetn(mem_aresetn[DDR_CHANNEL1]),

.s1_axi_awid(s_axi_awid[DDR_CHANNEL1]),
.s1_axi_awaddr(s_axi_awaddr[DDR_CHANNEL1]),
.s1_axi_awlen(s_axi_awlen[DDR_CHANNEL1]),
.s1_axi_awsize(s_axi_awsize[DDR_CHANNEL1]),
.s1_axi_awburst(s_axi_awburst[DDR_CHANNEL1]),
.s1_axi_awlock(s_axi_awlock[DDR_CHANNEL1]),
.s1_axi_awcache(s_axi_awcache[DDR_CHANNEL1]),
.s1_axi_awprot(s_axi_awprot[DDR_CHANNEL1]),
.s1_axi_awvalid(s_axi_awvalid[DDR_CHANNEL1]),
.s1_axi_awready(s_axi_awready[DDR_CHANNEL1]),

.s1_axi_wdata(s_axi_wdata[DDR_CHANNEL1]),
.s1_axi_wstrb(s_axi_wstrb[DDR_CHANNEL1]),
.s1_axi_wlast(s_axi_wlast[DDR_CHANNEL1]),
.s1_axi_wvalid(s_axi_wvalid[DDR_CHANNEL1]),
.s1_axi_wready(s_axi_wready[DDR_CHANNEL1]),

.s1_axi_bready(s_axi_bready[DDR_CHANNEL1]),
.s1_axi_bid(s_axi_bid[DDR_CHANNEL1]),
.s1_axi_bresp(s_axi_bresp[DDR_CHANNEL1]),
.s1_axi_bvalid(s_axi_bvalid[DDR_CHANNEL1]),

.s1_axi_arid(s_axi_arid[DDR_CHANNEL1]),
.s1_axi_araddr(s_axi_araddr[DDR_CHANNEL1]),
.s1_axi_arlen(s_axi_arlen[DDR_CHANNEL1]),
.s1_axi_arsize(s_axi_arsize[DDR_CHANNEL1]),
.s1_axi_arburst(s_axi_arburst[DDR_CHANNEL1]),
.s1_axi_arlock(s_axi_arlock[DDR_CHANNEL1]),
.s1_axi_arcache(s_axi_arcache[DDR_CHANNEL1]),
.s1_axi_arprot(s_axi_arprot[DDR_CHANNEL1]),
.s1_axi_arvalid(s_axi_arvalid[DDR_CHANNEL1]),
.s1_axi_arready(s_axi_arready[DDR_CHANNEL1]),

.s1_axi_rready(s_axi_rready[DDR_CHANNEL1]),
.s1_axi_rid(s_axi_rid[DDR_CHANNEL1]),
.s1_axi_rdata(s_axi_rdata[DDR_CHANNEL1]),
.s1_axi_rresp(s_axi_rresp[DDR_CHANNEL1]),
.s1_axi_rlast(s_axi_rlast[DDR_CHANNEL1]),
.s1_axi_rvalid(s_axi_rvalid[DDR_CHANNEL1])

);

`else
//A mem_clk is necessary for the DDR controller
assign mem_clk[DDR_CHANNEL0] = pcie_clk;
assign mem_aresetn[DDR_CHANNEL0] = pcie_aresetn;
assign mem_clk[DDR_CHANNEL1] = pcie_clk;
assign mem_aresetn[DDR_CHANNEL1] = pcie_aresetn;
`endif

 
/*
 * DMA Driver
 */
dma_driver dma_driver_inst (
  .sys_clk(pcie_ref_clk),                                              // input wire sys_clk
  .sys_rst_n(perst_n),                                          // input wire sys_rst_n
  .user_lnk_up(pcie_lnk_up),                                      // output wire user_lnk_up
  .pcie_tx_p(pcie_tx_p),                                      // output wire [7 : 0] pci_exp_txp
  .pcie_tx_n(pcie_tx_n),                                      // output wire [7 : 0] pci_exp_txn
  .pcie_rx_p(pcie_rx_p),                                      // input wire [7 : 0] pci_exp_rxp
  .pcie_rx_n(pcie_rx_n),                                      // input wire [7 : 0] pci_exp_rxn
  .pcie_clk(pcie_clk),                                            // output wire axi_aclk
  .pcie_aresetn(pcie_aresetn),                                      // output wire axi_aresetn
  //.usr_irq_req(1'b0),                                      // input wire [0 : 0] usr_irq_req
  //.usr_irq_ack(),                                      // output wire [0 : 0] usr_irq_ack
  //.msi_enable(),                                        // output wire msi_enable
  //.msi_vector_width(),                            // output wire [2 : 0] msi_vector_width
  
  // Axi Lite Control Master interface   
  .m_axil(axil_control),
  // AXI MM Control Interface 
  .m_axim(axim_control),
  
  // AXI Stream Interface
  .s_axis_c2h_tvalid_0(axis_dma_c2h.valid),                      // input wire s_axis_c2h_tvalid_0
  .s_axis_c2h_tready_0(axis_dma_c2h.ready),                      // output wire s_axis_c2h_tready_0
  .s_axis_c2h_tdata_0(axis_dma_c2h.data),                        // input wire [255 : 0] s_axis_c2h_tdata_0
  .s_axis_c2h_tkeep_0(axis_dma_c2h.keep),                        // input wire [31 : 0] s_axis_c2h_tkeep_0
  .s_axis_c2h_tlast_0(axis_dma_c2h.last),                        // input wire s_axis_c2h_tlast_0

  .m_axis_h2c_tvalid_0(axis_dma_h2c.valid),                      // output wire m_axis_h2c_tvalid_0
  .m_axis_h2c_tready_0(axis_dma_h2c.ready),                      // input wire m_axis_h2c_tready_0
  .m_axis_h2c_tdata_0(axis_dma_h2c.data),                        // output wire [255 : 0] m_axis_h2c_tdata_0
  .m_axis_h2c_tkeep_0(axis_dma_h2c.keep),                        // output wire [31 : 0] m_axis_h2c_tkeep_0
  .m_axis_h2c_tlast_0(axis_dma_h2c.last),                        // output wire m_axis_h2c_tlast_0

  // Descriptor Bypass
  .c2h_dsc_byp_ready_0    (c2h_dsc_byp_ready_0),
  //.c2h_dsc_byp_src_addr_0 (64'h0),
  .c2h_dsc_byp_addr_0     (c2h_dsc_byp_addr_0),
  .c2h_dsc_byp_len_0      (c2h_dsc_byp_len_0),
  //.c2h_dsc_byp_ctl_0      (16'h13), //was 16'h3
  .c2h_dsc_byp_load_0     (c2h_dsc_byp_load_0),
  
  .h2c_dsc_byp_ready_0    (h2c_dsc_byp_ready_0),
  .h2c_dsc_byp_addr_0     (h2c_dsc_byp_addr_0),
  //.h2c_dsc_byp_dst_addr_0 (64'h0),
  .h2c_dsc_byp_len_0      (h2c_dsc_byp_len_0),
  //.h2c_dsc_byp_ctl_0      (16'h13), //was 16'h3
  .h2c_dsc_byp_load_0     (h2c_dsc_byp_load_0),
  
  .c2h_sts_0(c2h_sts_0),                                          // output wire [7 : 0] c2h_sts_0
  .h2c_sts_0(h2c_sts_0)                                          // output wire [7 : 0] h2c_sts_0
);

/*
 * Operating System (not board-specific)
 */
os #(
`ifdef USE_DDR
    .ENABLE_DDR(1)
`else
    .ENABLE_DDR(0)
`endif
) os_inst(
    .pcie_clk(pcie_clk),
    .pcie_aresetn(pcie_aresetn),
    .mem_clk(mem_clk),
    .mem_aresetn(mem_aresetn),
    .net_clk(net_clk),
    .net_aresetn(net_aresetn),

    .user_clk(user_clk),
    .user_aresetn(user_aresetn),

    //Axi Lite Control
    .s_axil_control         (axil_control),
    // AXI MM Control Interface 
    .s_axim_control         (axim_control),
    
    //DDR
    .ddr_calib_complete(ddr_calib_complete),

    .m_axi_awid(s_axi_awid),
    .m_axi_awaddr(s_axi_awaddr),
    .m_axi_awlen(s_axi_awlen),
    .m_axi_awsize(s_axi_awsize),
    .m_axi_awburst(s_axi_awburst),
    .m_axi_awlock(s_axi_awlock),
    .m_axi_awcache(s_axi_awcache),
    .m_axi_awprot(s_axi_awprot),
    .m_axi_awvalid(s_axi_awvalid),
    .m_axi_awready(s_axi_awready),

    .m_axi_wdata(s_axi_wdata),
    .m_axi_wstrb(s_axi_wstrb),
    .m_axi_wlast(s_axi_wlast),
    .m_axi_wvalid(s_axi_wvalid),
    .m_axi_wready(s_axi_wready),

    .m_axi_bready(s_axi_bready),
    .m_axi_bid(s_axi_bid),
    .m_axi_bresp(s_axi_bresp),
    .m_axi_bvalid(s_axi_bvalid),

    .m_axi_arid(s_axi_arid),
    .m_axi_araddr(s_axi_araddr),
    .m_axi_arlen(s_axi_arlen),
    .m_axi_arsize(s_axi_arsize),
    .m_axi_arburst(s_axi_arburst),
    .m_axi_arlock(s_axi_arlock),
    .m_axi_arcache(s_axi_arcache),
    .m_axi_arprot(s_axi_arprot),
    .m_axi_arvalid(s_axi_arvalid),
    .m_axi_arready(s_axi_arready),

    .m_axi_rready(s_axi_rready),
    .m_axi_rid(s_axi_rid),
    .m_axi_rdata(s_axi_rdata),
    .m_axi_rresp(s_axi_rresp),
    .m_axi_rlast(s_axi_rlast),
    .m_axi_rvalid(s_axi_rvalid),


    //DMA
    .m_axis_dma_c2h(axis_dma_c2h),
    .s_axis_dma_h2c(axis_dma_h2c),

    .c2h_dsc_byp_load_0(c2h_dsc_byp_load_0),
    .c2h_dsc_byp_ready_0(c2h_dsc_byp_ready_0),
    .c2h_dsc_byp_addr_0(c2h_dsc_byp_addr_0),
    .c2h_dsc_byp_len_0(c2h_dsc_byp_len_0),

    .h2c_dsc_byp_load_0(h2c_dsc_byp_load_0),
    .h2c_dsc_byp_ready_0(h2c_dsc_byp_ready_0),
    .h2c_dsc_byp_addr_0(h2c_dsc_byp_addr_0),
    .h2c_dsc_byp_len_0(h2c_dsc_byp_len_0),

    .c2h_sts_0(c2h_sts_0),
    .h2c_sts_0(h2c_sts_0),

    //Network
    .s_axis_net_rx  (axis_net_rx_data),
    .m_axis_net_tx  (axis_net_tx_data)

);

endmodule

`default_nettype wire
