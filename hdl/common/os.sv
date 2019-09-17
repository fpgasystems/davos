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

`define POINTER_CHAISING

`include "davos_config.svh"
`include "davos_types.svh"

module os #(
    parameter AXI_ID_WIDTH = 1,
    parameter NUM_DDR_CHANNELS = 2, //TODO move
    parameter ENABLE_DDR = 1
) (
    input wire      pcie_clk,
    input wire      pcie_aresetn,
    input wire[NUM_DDR_CHANNELS-1:0]    mem_clk,
    input wire[NUM_DDR_CHANNELS-1:0]    mem_aresetn,
    input wire      net_clk,
    input wire      net_aresetn,
    output logic    user_clk,
    output logic    user_aresetn,

    // Axi Lite Control Interface
    axi_lite.slave      s_axil_control,  
    // AXI MM Control Interface 
    axi_mm.slave        s_axim_control,
    
    //DDR
    input wire          ddr_calib_complete,
    // Slave Interface Write Address Ports
    output logic [AXI_ID_WIDTH-1:0]                 m_axi_awid  [NUM_DDR_CHANNELS-1:0],
    output logic [31:0]                             m_axi_awaddr    [NUM_DDR_CHANNELS-1:0],
    output logic [7:0]                              m_axi_awlen [NUM_DDR_CHANNELS-1:0],
    output logic [2:0]                              m_axi_awsize    [NUM_DDR_CHANNELS-1:0],
    output logic [1:0]                              m_axi_awburst   [NUM_DDR_CHANNELS-1:0],
    output logic [0:0]                              m_axi_awlock    [NUM_DDR_CHANNELS-1:0],
    output logic [3:0]                              m_axi_awcache   [NUM_DDR_CHANNELS-1:0],
    output logic [2:0]                              m_axi_awprot    [NUM_DDR_CHANNELS-1:0],
    output logic[NUM_DDR_CHANNELS-1:0]                                    m_axi_awvalid,
    input wire[NUM_DDR_CHANNELS-1:0]                                      m_axi_awready,
    // Slave Interface Write Data Ports
    output logic [511:0]                            m_axi_wdata [NUM_DDR_CHANNELS-1:0],
    output logic [63:0]                             m_axi_wstrb [NUM_DDR_CHANNELS-1:0],
    output logic[NUM_DDR_CHANNELS-1:0]                                    m_axi_wlast,
    output logic[NUM_DDR_CHANNELS-1:0]                                    m_axi_wvalid,
    input wire[NUM_DDR_CHANNELS-1:0]                                      m_axi_wready,
    // Slave Interface Write Response Ports
    output logic[NUM_DDR_CHANNELS-1:0]                                    m_axi_bready,
    input wire [AXI_ID_WIDTH-1:0]                   m_axi_bid   [NUM_DDR_CHANNELS-1:0],
    input wire [1:0]                                m_axi_bresp [NUM_DDR_CHANNELS-1:0],
    input wire[NUM_DDR_CHANNELS-1:0]                                      m_axi_bvalid,
    // Slave Interface Read Address Ports
    output logic [AXI_ID_WIDTH-1:0]                 m_axi_arid  [NUM_DDR_CHANNELS-1:0],
    output logic [31:0]                             m_axi_araddr    [NUM_DDR_CHANNELS-1:0],
    output logic [7:0]                              m_axi_arlen [NUM_DDR_CHANNELS-1:0],
    output logic [2:0]                              m_axi_arsize    [NUM_DDR_CHANNELS-1:0],
    output logic [1:0]                              m_axi_arburst   [NUM_DDR_CHANNELS-1:0],
    output logic [0:0]                              m_axi_arlock    [NUM_DDR_CHANNELS-1:0],
    output logic [3:0]                              m_axi_arcache   [NUM_DDR_CHANNELS-1:0],
    output logic [2:0]                              m_axi_arprot    [NUM_DDR_CHANNELS-1:0],
    output logic[NUM_DDR_CHANNELS-1:0]                                    m_axi_arvalid,
    input wire[NUM_DDR_CHANNELS-1:0]                                      m_axi_arready,
    // Slave Interface Read Data Ports
    output logic[NUM_DDR_CHANNELS-1:0]                                    m_axi_rready,
    input wire [AXI_ID_WIDTH-1:0]                   m_axi_rid   [NUM_DDR_CHANNELS-1:0],
    input wire [511:0]                              m_axi_rdata [NUM_DDR_CHANNELS-1:0],
    input wire [1:0]                                m_axi_rresp [NUM_DDR_CHANNELS-1:0],
    input wire[NUM_DDR_CHANNELS-1:0]                                      m_axi_rlast,
    input wire[NUM_DDR_CHANNELS-1:0]                                      m_axi_rvalid,

    /* DMA */
    // AXI Stream Interface
    axi_stream.master       m_axis_dma_c2h,
    axi_stream.slave    s_axis_dma_h2c,

    // Descriptor Bypass
    input wire          c2h_dsc_byp_ready_0,
    //input wire[63:0]    c2h_dsc_byp_src_addr_0,
    output logic[63:0]  c2h_dsc_byp_addr_0,
    output logic[31:0]  c2h_dsc_byp_len_0,
    //input wire[15:0]    c2h_dsc_byp_ctl_0,
    output logic        c2h_dsc_byp_load_0,
    
    input wire          h2c_dsc_byp_ready_0,
    output logic[63:0]  h2c_dsc_byp_addr_0,
    //input wire[63:0]    h2c_dsc_byp_dst_addr_0,
    output logic[31:0]  h2c_dsc_byp_len_0,
    //input wire[15:0]    h2c_dsc_byp_ctl_0,
    output logic        h2c_dsc_byp_load_0,
    
    input wire[7:0]     c2h_sts_0,
    input wire[7:0]     h2c_sts_0,

    //Network
    axi_stream.slave    s_axis_net_rx[NUM_NET_PORTS],
    axi_stream.master   m_axis_net_tx[NUM_NET_PORTS]            // MOC netbt_tx -> net_tx


);

// Axi Lite Control Signals
localparam NUM_AXIL_MODULES = 5;
localparam AxilPortUserRole = 0; //TODO enum
localparam AxilPortDMA = 1;
localparam AxilPortDDR0 = 2;
localparam AxilPortDDR1 = 3;
localparam AxilPortNetwork = 4;

axi_lite        axil_to_modules[NUM_AXIL_MODULES]();

// Memory Signals
axis_mem_cmd    axis_mem_read_cmd[NUM_DDR_CHANNELS]();
axi_stream      axis_mem_read_data[NUM_DDR_CHANNELS]();
axis_mem_status axis_mem_read_status[NUM_DDR_CHANNELS](); 

axis_mem_cmd    axis_mem_write_cmd[NUM_DDR_CHANNELS]();
axi_stream      axis_mem_write_data[NUM_DDR_CHANNELS]();
axis_mem_status axis_mem_write_status[NUM_DDR_CHANNELS]();

//Role DDR interface
axis_mem_cmd    axis_role_mem_read_cmd[NUM_DDR_CHANNELS]();
axi_stream      axis_role_mem_read_data[NUM_DDR_CHANNELS]();
axis_mem_status axis_role_mem_read_status[NUM_DDR_CHANNELS](); 

axis_mem_cmd    axis_role_mem_write_cmd[NUM_DDR_CHANNELS]();
axi_stream      axis_role_mem_write_data[NUM_DDR_CHANNELS]();
axis_mem_status axis_role_mem_write_status[NUM_DDR_CHANNELS]();

//TCP/IP DDR interface
axis_mem_cmd    axis_tcp_mem_read_cmd[NUM_TCP_CHANNELS]();
axi_stream      axis_tcp_mem_read_data[NUM_TCP_CHANNELS]();
axis_mem_status axis_tcp_mem_read_status[NUM_TCP_CHANNELS](); 

axis_mem_cmd    axis_tcp_mem_write_cmd[NUM_TCP_CHANNELS]();
axi_stream      axis_tcp_mem_write_data[NUM_TCP_CHANNELS]();
axis_mem_status axis_tcp_mem_write_status[NUM_TCP_CHANNELS]();


// DMA Signals
axis_mem_cmd    axis_dma_role_read_cmd();
axis_mem_cmd    axis_dma_role_write_cmd();
axi_stream      axis_dma_role_read_data();
axi_stream      axis_dma_role_write_data();

axis_mem_cmd    axis_dma_roce_read_cmd();
axis_mem_cmd    axis_dma_roce_write_cmd();
axi_stream      axis_dma_roce_read_data();
axi_stream      axis_dma_roce_write_data();

axis_mem_cmd    axis_dma_read_cmd();
axis_mem_cmd    axis_dma_write_cmd();
axi_stream      axis_dma_read_data();
axi_stream      axis_dma_write_data();

// Network Signals
axis_meta           axis_roce_read_cmd();
axis_meta           axis_roce_write_cmd();
axi_stream          axis_roce_read_data();
axi_stream          axis_roce_write_data();
axis_meta #(.WIDTH(160))    axis_roce_role_tx_meta();
axi_stream          axis_roce_role_tx_data();

axis_meta           axis_roce_read_cmd_to_role();
axis_meta           axis_roce_write_cmd_to_role();
axi_stream          axis_roce_write_data_to_role();

axis_meta           axis_roce_read_cmd_to_merge();
axis_meta           axis_roce_write_cmd_to_merge();
axi_stream          axis_roce_write_data_to_merge();

// TCP/IP
axis_meta #(.WIDTH(16))     axis_tcp_listen_port();
axis_meta #(.WIDTH(8))      axis_tcp_port_status();
axis_meta #(.WIDTH(48))     axis_tcp_open_connection();
axis_meta #(.WIDTH(24))     axis_tcp_open_status();
axis_meta #(.WIDTH(16))     axis_tcp_close_connection();
axis_meta #(.WIDTH(88))     axis_tcp_notification();
axis_meta #(.WIDTH(32))     axis_tcp_read_pkg();

axis_meta #(.WIDTH(16))     axis_tcp_rx_meta();
axi_stream #(.WIDTH(NETWORK_STACK_WIDTH))    axis_tcp_rx_data();
axis_meta #(.WIDTH(32))     axis_tcp_tx_meta();
axi_stream #(.WIDTH(NETWORK_STACK_WIDTH))    axis_tcp_tx_data();
axis_meta #(.WIDTH(64))     axis_tcp_tx_status();

// UDP/IP
axis_meta #(.WIDTH(176))    axis_udp_rx_metadata();
axis_meta #(.WIDTH(176))    axis_udp_tx_metadata();

axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_udp_rx_data();
axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_udp_tx_data();

/*
 * User Role
 */
role_wrapper #(
    .NUM_ROLE_DDR_CHANNELS(NUM_DDR_CHANNELS - NUM_TCP_CHANNELS)
) user_role_wrapper (
    .net_clk(net_clk),
    .net_aresetn(net_aresetn),
    .pcie_clk(pcie_clk),
    .pcie_aresetn(pcie_aresetn),

    .user_clk(user_clk),
    .user_aresetn(user_aresetn),

    /* CONTROL INTERFACE */
    // LITE interface
    .s_axil         (axil_to_modules[AxilPortUserRole]),

    /* NETWORK - TCP/IP INTERFACWE */
    .m_axis_listen_port(axis_tcp_listen_port),
    .s_axis_listen_port_status(axis_tcp_port_status),
    .m_axis_open_connection(axis_tcp_open_connection),
    .s_axis_open_status(axis_tcp_open_status),
    .m_axis_close_connection(axis_tcp_close_connection),
    .s_axis_notifications(axis_tcp_notification),
    .m_axis_read_package(axis_tcp_read_pkg),
    .s_axis_rx_metadata(axis_tcp_rx_meta),
    .s_axis_rx_data(axis_tcp_rx_data),
    .m_axis_tx_metadata(axis_tcp_tx_meta),
    .m_axis_tx_data(axis_tcp_tx_data),
    .s_axis_tx_status(axis_tcp_tx_status),
    
    /* NETWORK - UDP/IP INTERFACE */
    .s_axis_udp_rx_metadata(axis_udp_rx_metadata),
    .s_axis_udp_rx_data(axis_udp_rx_data),
    .m_axis_udp_tx_metadata(axis_udp_tx_metadata),
    .m_axis_udp_tx_data(axis_udp_tx_data),

    /* NETWORK - RDMA INTERFACWE */
    .s_axis_roce_rx_read_cmd(axis_roce_read_cmd_to_role),
    .s_axis_roce_rx_write_cmd(axis_roce_write_cmd_to_role),
    .s_axis_roce_rx_write_data(axis_roce_write_data_to_role),
    .m_axis_roce_tx_meta(axis_roce_role_tx_meta),
    .m_axis_roce_tx_data(axis_roce_role_tx_data),


    /* MEMORY INTERFACE */
    .m_axis_mem_read_cmd(axis_role_mem_read_cmd),
    .m_axis_mem_write_cmd(axis_role_mem_write_cmd),
    .s_axis_mem_read_data(axis_role_mem_read_data),
    .m_axis_mem_write_data(axis_role_mem_write_data),
    .s_axis_mem_read_status(axis_role_mem_read_status),
    .s_axis_mem_write_status(axis_role_mem_write_status),

    /* DMA INTERFACE */
    .m_axis_dma_read_cmd    (axis_dma_role_read_cmd),
    .m_axis_dma_write_cmd   (axis_dma_role_write_cmd),

    .s_axis_dma_read_data   (axis_dma_role_read_data),
    .m_axis_dma_write_data  (axis_dma_role_write_data)

);


/*
 * Memory Interface
 */
//TODO move
localparam DDR_CHANNEL0 = 0;
localparam DDR_CHANNEL1 = 1;

mem_single_inf #(
    .ENABLE(ENABLE_DDR),
    .UNALIGNED(0 < NUM_TCP_CHANNELS)
) mem_inf_inst0 (
.user_clk(user_clk),
.user_aresetn(ddr_calib_complete),
.pcie_clk(pcie_clk), //TODO remove
.pcie_aresetn(pcie_aresetn),
.mem_clk(mem_clk[DDR_CHANNEL0]),
.mem_aresetn(mem_aresetn[DDR_CHANNEL0]),

/* USER INTERFACE */
//memory read commands
.s_axis_mem_read_cmd(axis_mem_read_cmd[DDR_CHANNEL0]),
//memory read status
.m_axis_mem_read_status(axis_mem_read_status[DDR_CHANNEL0]),
//memory read stream
.m_axis_mem_read_data(axis_mem_read_data[DDR_CHANNEL0]),

//memory write commands
.s_axis_mem_write_cmd(axis_mem_write_cmd[DDR_CHANNEL0]),
//memory rite status
.m_axis_mem_write_status(axis_mem_write_status[DDR_CHANNEL0]),
//memory write stream
.s_axis_mem_write_data(axis_mem_write_data[DDR_CHANNEL0]),

/* CONTROL INTERFACE */
// LITE interface
.s_axil(axil_to_modules[AxilPortDDR0]),

/* DRIVER INTERFACE */
.m_axi_awid(m_axi_awid[DDR_CHANNEL0]),
.m_axi_awaddr(m_axi_awaddr[DDR_CHANNEL0]),
.m_axi_awlen(m_axi_awlen[DDR_CHANNEL0]),
.m_axi_awsize(m_axi_awsize[DDR_CHANNEL0]),
.m_axi_awburst(m_axi_awburst[DDR_CHANNEL0]),
.m_axi_awlock(m_axi_awlock[DDR_CHANNEL0]),
.m_axi_awcache(m_axi_awcache[DDR_CHANNEL0]),
.m_axi_awprot(m_axi_awprot[DDR_CHANNEL0]),
.m_axi_awvalid(m_axi_awvalid[DDR_CHANNEL0]),
.m_axi_awready(m_axi_awready[DDR_CHANNEL0]),

.m_axi_wdata(m_axi_wdata[DDR_CHANNEL0]),
.m_axi_wstrb(m_axi_wstrb[DDR_CHANNEL0]),
.m_axi_wlast(m_axi_wlast[DDR_CHANNEL0]),
.m_axi_wvalid(m_axi_wvalid[DDR_CHANNEL0]),
.m_axi_wready(m_axi_wready[DDR_CHANNEL0]),

.m_axi_bready(m_axi_bready[DDR_CHANNEL0]),
.m_axi_bid(m_axi_bid[DDR_CHANNEL0]),
.m_axi_bresp(m_axi_bresp[DDR_CHANNEL0]),
.m_axi_bvalid(m_axi_bvalid[DDR_CHANNEL0]),

.m_axi_arid(m_axi_arid[DDR_CHANNEL0]),
.m_axi_araddr(m_axi_araddr[DDR_CHANNEL0]),
.m_axi_arlen(m_axi_arlen[DDR_CHANNEL0]),
.m_axi_arsize(m_axi_arsize[DDR_CHANNEL0]),
.m_axi_arburst(m_axi_arburst[DDR_CHANNEL0]),
.m_axi_arlock(m_axi_arlock[DDR_CHANNEL0]),
.m_axi_arcache(m_axi_arcache[DDR_CHANNEL0]),
.m_axi_arprot(m_axi_arprot[DDR_CHANNEL0]),
.m_axi_arvalid(m_axi_arvalid[DDR_CHANNEL0]),
.m_axi_arready(m_axi_arready[DDR_CHANNEL0]),

.m_axi_rready(m_axi_rready[DDR_CHANNEL0]),
.m_axi_rid(m_axi_rid[DDR_CHANNEL0]),
.m_axi_rdata(m_axi_rdata[DDR_CHANNEL0]),
.m_axi_rresp(m_axi_rresp[DDR_CHANNEL0]),
.m_axi_rlast(m_axi_rlast[DDR_CHANNEL0]),
.m_axi_rvalid(m_axi_rvalid[DDR_CHANNEL0])
);

mem_single_inf #(
    .ENABLE(ENABLE_DDR),
    .UNALIGNED(1 < NUM_TCP_CHANNELS)
) mem_inf_inst1 (
.user_clk(user_clk),
.user_aresetn(ddr_calib_complete),
.pcie_clk(pcie_clk),
.pcie_aresetn(pcie_aresetn), //TODO remove
.mem_clk(mem_clk[DDR_CHANNEL1]),
.mem_aresetn(mem_aresetn[DDR_CHANNEL1]),


/* USER INTERFACE */
.s_axis_mem_read_cmd(axis_mem_read_cmd[DDR_CHANNEL1]),
//memory read status
.m_axis_mem_read_status(axis_mem_read_status[DDR_CHANNEL1]),
//memory read stream
.m_axis_mem_read_data(axis_mem_read_data[DDR_CHANNEL1]),

//memory write commands
.s_axis_mem_write_cmd(axis_mem_write_cmd[DDR_CHANNEL1]),
//memory rite status
.m_axis_mem_write_status(axis_mem_write_status[DDR_CHANNEL1]),
//memory write stream
.s_axis_mem_write_data(axis_mem_write_data[DDR_CHANNEL1]),

/* CONTROL INTERFACE */
// LITE interface
.s_axil(axil_to_modules[AxilPortDDR1]),

/* DRIVER INTERFACE */
.m_axi_awid(m_axi_awid[DDR_CHANNEL1]),
.m_axi_awaddr(m_axi_awaddr[DDR_CHANNEL1]),
.m_axi_awlen(m_axi_awlen[DDR_CHANNEL1]),
.m_axi_awsize(m_axi_awsize[DDR_CHANNEL1]),
.m_axi_awburst(m_axi_awburst[DDR_CHANNEL1]),
.m_axi_awlock(m_axi_awlock[DDR_CHANNEL1]),
.m_axi_awcache(m_axi_awcache[DDR_CHANNEL1]),
.m_axi_awprot(m_axi_awprot[DDR_CHANNEL1]),
.m_axi_awvalid(m_axi_awvalid[DDR_CHANNEL1]),
.m_axi_awready(m_axi_awready[DDR_CHANNEL1]),

.m_axi_wdata(m_axi_wdata[DDR_CHANNEL1]),
.m_axi_wstrb(m_axi_wstrb[DDR_CHANNEL1]),
.m_axi_wlast(m_axi_wlast[DDR_CHANNEL1]),
.m_axi_wvalid(m_axi_wvalid[DDR_CHANNEL1]),
.m_axi_wready(m_axi_wready[DDR_CHANNEL1]),

.m_axi_bready(m_axi_bready[DDR_CHANNEL1]),
.m_axi_bid(m_axi_bid[DDR_CHANNEL1]),
.m_axi_bresp(m_axi_bresp[DDR_CHANNEL1]),
.m_axi_bvalid(m_axi_bvalid[DDR_CHANNEL1]),

.m_axi_arid(m_axi_arid[DDR_CHANNEL1]),
.m_axi_araddr(m_axi_araddr[DDR_CHANNEL1]),
.m_axi_arlen(m_axi_arlen[DDR_CHANNEL1]),
.m_axi_arsize(m_axi_arsize[DDR_CHANNEL1]),
.m_axi_arburst(m_axi_arburst[DDR_CHANNEL1]),
.m_axi_arlock(m_axi_arlock[DDR_CHANNEL1]),
.m_axi_arcache(m_axi_arcache[DDR_CHANNEL1]),
.m_axi_arprot(m_axi_arprot[DDR_CHANNEL1]),
.m_axi_arvalid(m_axi_arvalid[DDR_CHANNEL1]),
.m_axi_arready(m_axi_arready[DDR_CHANNEL1]),

.m_axi_rready(m_axi_rready[DDR_CHANNEL1]),
.m_axi_rid(m_axi_rid[DDR_CHANNEL1]),
.m_axi_rdata(m_axi_rdata[DDR_CHANNEL1]),
.m_axi_rresp(m_axi_rresp[DDR_CHANNEL1]),
.m_axi_rlast(m_axi_rlast[DDR_CHANNEL1]),
.m_axi_rvalid(m_axi_rvalid[DDR_CHANNEL1])
);


 
/*
 * DMA Interface
 */

dma_inf dma_interface (
    .pcie_clk(pcie_clk),
    .pcie_aresetn(pcie_aresetn),
    .user_clk(user_clk),
    .user_aresetn(user_aresetn),

    /* USER INTERFACE */
    .s_axis_dma_read_cmd            (axis_dma_read_cmd),
    .s_axis_dma_write_cmd           (axis_dma_write_cmd),

    .m_axis_dma_read_data           (axis_dma_read_data),
    .s_axis_dma_write_data          (axis_dma_write_data),

    /* DRIVER INTERFACE */
    // Control interface
    .s_axil(axil_to_modules[AxilPortDMA]),

    // Data
    .m_axis_c2h_data(m_axis_dma_c2h),
    .s_axis_h2c_data(s_axis_dma_h2c),

    .c2h_dsc_byp_load_0(c2h_dsc_byp_load_0),
    .c2h_dsc_byp_ready_0(c2h_dsc_byp_ready_0),
    .c2h_dsc_byp_addr_0(c2h_dsc_byp_addr_0),
    .c2h_dsc_byp_len_0(c2h_dsc_byp_len_0),

    .h2c_dsc_byp_load_0(h2c_dsc_byp_load_0),
    .h2c_dsc_byp_ready_0(h2c_dsc_byp_ready_0),
    .h2c_dsc_byp_addr_0(h2c_dsc_byp_addr_0),
    .h2c_dsc_byp_len_0(h2c_dsc_byp_len_0),

    .c2h_sts_0(c2h_sts_0),
    .h2c_sts_0(h2c_sts_0)

);

/*
 * Network Stack
 */
network_stack #(
    .WIDTH(NETWORK_STACK_WIDTH),
    .TCP_EN(TCP_STACK_EN),
    .RX_DDR_BYPASS_EN(TCP_RX_BYPASS_EN),
    .UDP_EN(UDP_STACK_EN),
    .ROCE_EN(ROCE_STACK_EN)
) network_stack_inst (
    .net_clk(net_clk),
    .net_aresetn(net_aresetn),
    .pcie_clk(pcie_clk),
    .pcie_aresetn(pcie_aresetn),

    //Control interface
    .s_axil(axil_to_modules[AxilPortNetwork]),
    .s_axim(s_axim_control),
    
    //Streams from/to Network interface
    .m_axis_net(m_axis_net_tx[0]),
    .s_axis_net(s_axis_net_rx[0]),

    //RoCE interface
    .m_axis_roce_read_cmd(axis_roce_read_cmd),
    .m_axis_roce_write_cmd(axis_roce_write_cmd),
    .s_axis_roce_read_data(axis_roce_read_data),
    .m_axis_roce_write_data(axis_roce_write_data),
    //Role interface
    .s_axis_roce_role_tx_meta(axis_roce_role_tx_meta),
    .s_axis_roce_role_tx_data(axis_roce_role_tx_data),

    //TCP/IP interface
    .m_axis_read_cmd(axis_tcp_mem_read_cmd),
    .m_axis_write_cmd(axis_tcp_mem_write_cmd),
    .s_axis_read_sts(axis_tcp_mem_read_status),
    .s_axis_write_sts(axis_tcp_mem_write_status),
    .s_axis_read_data(axis_tcp_mem_read_data),
    .m_axis_write_data(axis_tcp_mem_write_data),
   
    //Role interface
    .s_axis_listen_port(axis_tcp_listen_port),
    .m_axis_listen_port_status(axis_tcp_port_status),
    .s_axis_open_connection(axis_tcp_open_connection),
    .m_axis_open_status(axis_tcp_open_status),
    .s_axis_close_connection(axis_tcp_close_connection),
    .m_axis_notifications(axis_tcp_notification),
    .s_axis_read_package(axis_tcp_read_pkg),
    .m_axis_rx_metadata(axis_tcp_rx_meta),
    .m_axis_rx_data(axis_tcp_rx_data),
    .s_axis_tx_metadata(axis_tcp_tx_meta),
    .s_axis_tx_data(axis_tcp_tx_data),
    .m_axis_tx_status(axis_tcp_tx_status),

//pointer chasing
`ifdef POINTER_CHAISING
.m_axis_rx_pcmeta            (axis_rx_pc_meta),
.s_axis_tx_pcmeta             (axis_tx_pc_meta),
`endif

    /* NETWORK - UDP/IP INTERFACE */
    .m_axis_udp_rx_metadata(axis_udp_rx_metadata),
    .m_axis_udp_rx_data(axis_udp_rx_data),
    .s_axis_udp_tx_metadata(axis_udp_tx_metadata),
    .s_axis_udp_tx_data(axis_udp_tx_data)
);
axis_meta   axis_rx_pc_meta();
axis_meta   axis_tx_pc_meta();
assign axis_rx_pc_meta.ready = 1'b1;
assign axis_tx_pc_meta.valid = 1'b0;
assign axis_tx_pc_meta.data = '0;


//TODO handle second network port
assign s_axis_net_rx[1].ready = 1'b1;
/*
assign m_axis_net_tx[1].valid = 1'b0;
assign m_axis_net_tx[1].data = '0;
assign m_axis_net_tx[1].keep = '0;
assign m_axis_net_tx[1].last = 1'b0;*/

//MOC: add mirroring for wireshark debugging
assign m_axis_net_tx[1].valid = m_axis_net_tx[0].valid;
assign m_axis_net_tx[1].data  = m_axis_net_tx[0].data;
assign m_axis_net_tx[1].keep  = m_axis_net_tx[0].keep;
assign m_axis_net_tx[1].last  = m_axis_net_tx[0].last;

/*
 * Splitting of commands
 */
axis_interconnect_96_1to2 axis_roce_read_cmd_split (
  .ACLK(user_clk),
  .ARESETN(user_aresetn),
  .S00_AXIS_ACLK(user_clk),
  .S00_AXIS_ARESETN(user_aresetn),
  .S00_AXIS_TVALID(axis_roce_read_cmd.valid),
  .S00_AXIS_TREADY(axis_roce_read_cmd.ready),
  .S00_AXIS_TDATA(axis_roce_read_cmd.data),
  .S00_AXIS_TDEST(axis_roce_read_cmd.dest),
  //DMA
  .M00_AXIS_ACLK(user_clk),
  .M00_AXIS_ARESETN(user_aresetn),
  .M00_AXIS_TVALID(axis_roce_read_cmd_to_merge.valid),
  .M00_AXIS_TREADY(axis_roce_read_cmd_to_merge.ready),
  .M00_AXIS_TDATA(axis_roce_read_cmd_to_merge.data),
  .M00_AXIS_TDEST(),
  //Role
  .M01_AXIS_ACLK(user_clk),
  .M01_AXIS_ARESETN(user_aresetn),
  .M01_AXIS_TVALID(axis_roce_read_cmd_to_role.valid),
  .M01_AXIS_TREADY(axis_roce_read_cmd_to_role.ready),
  .M01_AXIS_TDATA(axis_roce_read_cmd_to_role.data),
  .M01_AXIS_TDEST(),
  
  .S00_DECODE_ERR()
);

axis_interconnect_96_1to2 axis_roce_write_cmd_split (
  .ACLK(user_clk),
  .ARESETN(user_aresetn),
  .S00_AXIS_ACLK(user_clk),
  .S00_AXIS_ARESETN(user_aresetn),
  .S00_AXIS_TVALID(axis_roce_write_cmd.valid),
  .S00_AXIS_TREADY(axis_roce_write_cmd.ready),
  .S00_AXIS_TDATA(axis_roce_write_cmd.data),
  .S00_AXIS_TDEST(axis_roce_write_cmd.dest),
  //DMA
  .M00_AXIS_ACLK(user_clk),
  .M00_AXIS_ARESETN(user_aresetn),
  .M00_AXIS_TVALID(axis_roce_write_cmd_to_merge.valid),
  .M00_AXIS_TREADY(axis_roce_write_cmd_to_merge.ready),
  .M00_AXIS_TDATA(axis_roce_write_cmd_to_merge.data),
  .M00_AXIS_TDEST(),
  //Role
  .M01_AXIS_ACLK(user_clk),
  .M01_AXIS_ARESETN(user_aresetn),
  .M01_AXIS_TVALID(axis_roce_write_cmd_to_role.valid),
  .M01_AXIS_TREADY(axis_roce_write_cmd_to_role.ready),
  .M01_AXIS_TDATA(axis_roce_write_cmd_to_role.data),
  .M01_AXIS_TDEST(),
  
  .S00_DECODE_ERR()
);


axis_interconnect_512_1to2 axis_mem_write_split (
  .ACLK(user_clk),                          // input wire ACLK
  .ARESETN(user_aresetn),                    // input wire ARESETN
  .S00_AXIS_ACLK(user_clk),        // input wire S00_AXIS_ACLK
  .S00_AXIS_ARESETN(user_aresetn),  // input wire S00_AXIS_ARESETN
  .S00_AXIS_TVALID(axis_roce_write_data.valid),    // input wire S00_AXIS_TVALID
  .S00_AXIS_TREADY(axis_roce_write_data.ready),    // output wire S00_AXIS_TREADY
  .S00_AXIS_TDATA(axis_roce_write_data.data),      // input wire [63 : 0] S00_AXIS_TDATA
  .S00_AXIS_TKEEP(axis_roce_write_data.keep),      // input wire [7 : 0] S00_AXIS_TKEEP
  .S00_AXIS_TLAST(axis_roce_write_data.last),      // input wire S00_AXIS_TLAST
  .S00_AXIS_TDEST(axis_roce_write_data.dest),      // input wire [0 : 0] S00_AXIS_TDEST
  //DMA
  .M00_AXIS_ACLK(user_clk),        // input wire M01_AXIS_ACLK
  .M00_AXIS_ARESETN(user_aresetn),  // input wire M01_AXIS_ARESETN
  .M00_AXIS_TVALID(axis_roce_write_data_to_merge.valid),    // output wire M01_AXIS_TVALID
  .M00_AXIS_TREADY(axis_roce_write_data_to_merge.ready),    // input wire M01_AXIS_TREADY
  .M00_AXIS_TDATA(axis_roce_write_data_to_merge.data),      // output wire [63 : 0] M01_AXIS_TDATA
  .M00_AXIS_TKEEP(axis_roce_write_data_to_merge.keep),      // output wire [7 : 0] M01_AXIS_TKEEP
  .M00_AXIS_TLAST(axis_roce_write_data_to_merge.last),      // output wire M01_AXIS_TLAST
  .M00_AXIS_TDEST(),      // output wire [0 : 0] M01_AXIS_TDEST
  //Role
  .M01_AXIS_ACLK(user_clk),        // input wire M01_AXIS_ACLK
  .M01_AXIS_ARESETN(user_aresetn),  // input wire M01_AXIS_ARESETN
  .M01_AXIS_TVALID(axis_roce_write_data_to_role.valid),    // output wire M01_AXIS_TVALID
  .M01_AXIS_TREADY(axis_roce_write_data_to_role.ready),    // input wire M01_AXIS_TREADY
  .M01_AXIS_TDATA(axis_roce_write_data_to_role.data),      // output wire [63 : 0] M01_AXIS_TDATA
  .M01_AXIS_TKEEP(axis_roce_write_data_to_role.keep),      // output wire [7 : 0] M01_AXIS_TKEEP
  .M01_AXIS_TLAST(axis_roce_write_data_to_role.last),      // output wire M01_AXIS_TLAST
  .M01_AXIS_TDEST(),      // output wire [0 : 0] M01_AXIS_TDEST
  
  .S00_DECODE_ERR()      // output wire S00_DECODE_ERR
);

/*
 * Merging of commands
 */
mem_read_cmd_merger_512_ip mem_read_cmd_merger_inst (
  .m_axis_cmd_V_TVALID(axis_dma_read_cmd.valid),      // output wire m_axis_cmd_TVALID
  .m_axis_cmd_V_TREADY(axis_dma_read_cmd.ready),      // input wire m_axis_cmd_TREADY
  .m_axis_cmd_V_TDATA({axis_dma_read_cmd.length, axis_dma_read_cmd.address}),        // output wire [95 : 0] m_axis_cmd_TDATA
  .m_axis_data0_TVALID(axis_roce_read_data.valid),  // output wire m_axis_data0_TVALID
  .m_axis_data0_TREADY(axis_roce_read_data.ready),  // input wire m_axis_data0_TREADY
  .m_axis_data0_TDATA(axis_roce_read_data.data),    // output wire [255 : 0] m_axis_data0_TDATA
  .m_axis_data0_TKEEP(axis_roce_read_data.keep),    // output wire [31 : 0] m_axis_data0_TKEEP
  .m_axis_data0_TLAST(axis_roce_read_data.last),    // output wire [0 : 0] m_axis_data0_TLAST
  .m_axis_data1_TVALID(axis_dma_role_read_data.valid),  // output wire m_axis_data1_TVALID
  .m_axis_data1_TREADY(axis_dma_role_read_data.ready),  // input wire m_axis_data1_TREADY
  .m_axis_data1_TDATA(axis_dma_role_read_data.data),    // output wire [255 : 0] m_axis_data1_TDATA
  .m_axis_data1_TKEEP(axis_dma_role_read_data.keep),    // output wire [31 : 0] m_axis_data1_TKEEP
  .m_axis_data1_TLAST(axis_dma_role_read_data.last),    // output wire [0 : 0] m_axis_data1_TLAST
  .s_axis_cmd0_V_TVALID(axis_roce_read_cmd_to_merge.valid),    // input wire s_axis_cmd0_TVALID
  .s_axis_cmd0_V_TREADY(axis_roce_read_cmd_to_merge.ready),    // output wire s_axis_cmd0_TREADY
  .s_axis_cmd0_V_TDATA(axis_roce_read_cmd_to_merge.data),      // input wire [95 : 0] s_axis_cmd0_TDATA
  .s_axis_cmd1_V_TVALID(axis_dma_role_read_cmd.valid),    // input wire s_axis_cmd1_TVALID
  .s_axis_cmd1_V_TREADY(axis_dma_role_read_cmd.ready),    // output wire s_axis_cmd1_TREADY
  .s_axis_cmd1_V_TDATA({axis_dma_role_read_cmd.length, axis_dma_role_read_cmd.address}),      // input wire [95 : 0] s_axis_cmd1_TDATA
  .s_axis_data_TVALID(axis_dma_read_data.valid),    // input wire s_axis_data_TVALID
  .s_axis_data_TREADY(axis_dma_read_data.ready),    // output wire s_axis_data_TREADY
  .s_axis_data_TDATA(axis_dma_read_data.data),      // input wire [255 : 0] s_axis_data_TDATA
  .s_axis_data_TKEEP(axis_dma_read_data.keep),      // input wire [31 : 0] s_axis_data_TKEEP
  .s_axis_data_TLAST(axis_dma_read_data.last),      // input wire [0 : 0] s_axis_data_TLAST
  .ap_clk(user_clk),                                // input wire aclk
  .ap_rst_n(user_aresetn),                          // input wire aresetn
  .regbaseVaddr_V(0) //TODO
);
//Priority on cmd0/data0
mem_cmd_data_merger_512_ip dma_write_cmd_merger (
  .m_axis_cmd_V_TVALID(axis_dma_write_cmd.valid),      // output wire m_axis_cmd_TVALID
  .m_axis_cmd_V_TREADY(axis_dma_write_cmd.ready),      // input wire m_axis_cmd_TREADY
  .m_axis_cmd_V_TDATA({axis_dma_write_cmd.length, axis_dma_write_cmd.address}),        // output wire [111 : 0] m_axis_cmd_TDATA
  .m_axis_data_TVALID(axis_dma_write_data.valid),    // output wire m_axis_data_TVALID
  .m_axis_data_TREADY(axis_dma_write_data.ready),    // input wire m_axis_data_TREADY
  .m_axis_data_TDATA(axis_dma_write_data.data),      // output wire [255 : 0] m_axis_data_TDATA
  .m_axis_data_TKEEP(axis_dma_write_data.keep),      // output wire [31 : 0] m_axis_data_TKEEP
  .m_axis_data_TLAST(axis_dma_write_data.last),      // output wire [0 : 0] m_axis_data_TLAST
  .s_axis_cmd0_V_TVALID(axis_roce_write_cmd_to_merge.valid),    // input wire s_axis_cmd0_TVALID
  .s_axis_cmd0_V_TREADY(axis_roce_write_cmd_to_merge.ready),    // output wire s_axis_cmd0_TREADY
  .s_axis_cmd0_V_TDATA(axis_roce_write_cmd_to_merge.data),      // input wire [111 : 0] s_axis_cmd0_TDATA
  .s_axis_cmd1_V_TVALID(axis_dma_role_write_cmd.valid),    // input wire s_axis_cmd1_TVALID
  .s_axis_cmd1_V_TREADY(axis_dma_role_write_cmd.ready),    // output wire s_axis_cmd1_TREADY
  .s_axis_cmd1_V_TDATA({axis_dma_role_write_cmd.length, axis_dma_role_write_cmd.address}),      // input wire [111 : 0] s_axis_cmd1_TDATA
  .s_axis_data0_TVALID(axis_roce_write_data_to_merge.valid),  // input wire s_axis_data0_TVALID
  .s_axis_data0_TREADY(axis_roce_write_data_to_merge.ready),  // output wire s_axis_data0_TREADY
  .s_axis_data0_TDATA(axis_roce_write_data_to_merge.data),    // input wire [255 : 0] s_axis_data0_TDATA
  .s_axis_data0_TKEEP(axis_roce_write_data_to_merge.keep),    // input wire [31 : 0] s_axis_data0_TKEEP
  .s_axis_data0_TLAST(axis_roce_write_data_to_merge.last),    // input wire [0 : 0] s_axis_data0_TLAST
  .s_axis_data1_TVALID(axis_dma_role_write_data.valid),  // input wire s_axis_data1_TVALID
  .s_axis_data1_TREADY(axis_dma_role_write_data.ready),  // output wire s_axis_data1_TREADY
  .s_axis_data1_TDATA(axis_dma_role_write_data.data),    // input wire [255 : 0] s_axis_data1_TDATA
  .s_axis_data1_TKEEP(axis_dma_role_write_data.keep),    // input wire [31 : 0] s_axis_data1_TKEEP
  .s_axis_data1_TLAST(axis_dma_role_write_data.last),    // input wire [0 : 0] s_axis_data1_TLAST
  .ap_clk(user_clk),                                // input wire aclk
  .ap_rst_n(user_aresetn)                          // input wire aresetn
);
 
 /*
 * Axi Lite Controller Interconnect
 */
 axil_interconnect_done_right axi_controller_interconnect_inst (
    .aclk(pcie_clk),
    .aresetn(pcie_aresetn),

    .s_axil(s_axil_control),
    .m_axil(axil_to_modules)

);

/*
 * Switch DRAM access between TCP/IP stack and User Role
 */
generate
for (genvar i=0; i < NUM_DDR_CHANNELS;i++) begin
    if (i < NUM_TCP_CHANNELS) begin
        //command
        assign axis_mem_read_cmd[i].valid = axis_tcp_mem_read_cmd[i].valid;
        assign axis_tcp_mem_read_cmd[i].ready = axis_mem_read_cmd[i].ready;
        assign axis_mem_read_cmd[i].address = axis_tcp_mem_read_cmd[i].address;
        assign axis_mem_read_cmd[i].length = axis_tcp_mem_read_cmd[i].length;
        assign axis_mem_write_cmd[i].valid = axis_tcp_mem_write_cmd[i].valid;
        assign axis_tcp_mem_write_cmd[i].ready = axis_mem_write_cmd[i].ready;
        assign axis_mem_write_cmd[i].address = axis_tcp_mem_write_cmd[i].address;
        assign axis_mem_write_cmd[i].length = axis_tcp_mem_write_cmd[i].length;
        //data
        assign axis_tcp_mem_read_data[i].valid = axis_mem_read_data[i].valid;
        assign axis_mem_read_data[i].ready = axis_tcp_mem_read_data[i].ready;
        assign axis_tcp_mem_read_data[i].data = axis_mem_read_data[i].data;
        assign axis_tcp_mem_read_data[i].keep = axis_mem_read_data[i].keep;
        assign axis_tcp_mem_read_data[i].last = axis_mem_read_data[i].last;

        assign axis_mem_write_data[i].valid = axis_tcp_mem_write_data[i].valid;
        assign axis_tcp_mem_write_data[i].ready = axis_mem_write_data[i].ready;
        assign axis_mem_write_data[i].data = axis_tcp_mem_write_data[i].data;
        assign axis_mem_write_data[i].keep = axis_tcp_mem_write_data[i].keep;
        assign axis_mem_write_data[i].last = axis_tcp_mem_write_data[i].last;
        //status
        assign axis_tcp_mem_read_status[i].valid = axis_mem_read_status[i].valid;
        assign axis_mem_read_status[i].ready = axis_tcp_mem_read_status[i].ready;
        assign axis_tcp_mem_read_status[i].data = axis_mem_read_status[i].data;

        assign axis_tcp_mem_write_status[i].valid = axis_mem_write_status[i].valid;
        assign axis_mem_write_status[i].ready = axis_tcp_mem_write_status[i].ready;
        assign axis_tcp_mem_write_status[i].data = axis_mem_write_status[i].data;
    end
    else begin
        //command
        assign axis_tcp_mem_read_cmd[i].ready = 1'b0;
        assign axis_tcp_mem_write_cmd[i].ready = 1'b0;
        //data
        assign axis_tcp_mem_read_data[i].valid = 1'b0;
        assign axis_tcp_mem_read_data[i].data = 0;
        assign axis_tcp_mem_read_data[i].keep = 0;
        assign axis_tcp_mem_read_data[i].last = 0;

        assign axis_tcp_mem_write_data[i].ready = 1'b0;
        //status
        assign axis_tcp_mem_read_status[i].valid = 1'b0;
        assign axis_tcp_mem_read_status[i].data = 0;

        assign axis_tcp_mem_write_status[i].valid = 1'b0;
        assign axis_tcp_mem_write_status[i].data = 0;
    end
end//for
endgenerate

generate
for (genvar i=0; i < NUM_DDR_CHANNELS;i++) begin
    localparam integer j = NUM_TCP_CHANNELS + i;
    if (i < NUM_DDR_CHANNELS - NUM_TCP_CHANNELS) begin
        //command
        assign axis_mem_read_cmd[j].valid = axis_role_mem_read_cmd[i].valid;
        assign axis_role_mem_read_cmd[i].ready = axis_mem_read_cmd[j].ready;
        assign axis_mem_read_cmd[j].address = axis_role_mem_read_cmd[i].address;
        assign axis_mem_read_cmd[j].length= axis_role_mem_read_cmd[i].length;
        assign axis_mem_write_cmd[j].valid = axis_role_mem_write_cmd[i].valid;
        assign axis_role_mem_write_cmd[i].ready = axis_mem_write_cmd[j].ready;
        assign axis_mem_write_cmd[j].address = axis_role_mem_write_cmd[i].data;
        assign axis_mem_write_cmd[j].length = axis_role_mem_write_cmd[i].length;
        //data
        assign axis_role_mem_read_data[i].valid = axis_mem_read_data[j].valid;
        assign axis_mem_read_data[j].ready = axis_role_mem_read_data[i].ready;
        assign axis_role_mem_read_data[i].data = axis_mem_read_data[j].data;
        assign axis_role_mem_read_data[i].keep = axis_mem_read_data[j].keep;
        assign axis_role_mem_read_data[i].last = axis_mem_read_data[j].last;

        assign axis_mem_write_data[j].valid = axis_role_mem_write_data[i].valid;
        assign axis_role_mem_write_data[i].ready = axis_mem_write_data[j].ready;
        assign axis_mem_write_data[j].data = axis_role_mem_write_data[i].data;
        assign axis_mem_write_data[j].keep = axis_role_mem_write_data[i].keep;
        assign axis_mem_write_data[j].last = axis_role_mem_write_data[i].last;
        //status
        assign axis_role_mem_read_status[i].valid = axis_mem_read_status[j].valid;
        assign axis_mem_read_status[j].ready = axis_role_mem_read_status[i].ready;
        assign axis_role_mem_read_status[i].data = axis_mem_read_status[j].data;

        assign axis_role_mem_write_status[i].valid = axis_mem_write_status[j].valid;
        assign axis_mem_write_status[j].ready = axis_role_mem_write_status[i].ready;
        assign axis_role_mem_write_status[i].data = axis_mem_write_status[j].data;
    end
    else begin
        //command
        assign axis_role_mem_read_cmd[i].ready = 1'b0;
        assign axis_role_mem_write_cmd[i].ready = 1'b0;
        //data
        assign axis_role_mem_read_data[i].valid = 1'b0;
        assign axis_role_mem_read_data[i].data = 0;
        assign axis_role_mem_read_data[i].keep = 0;
        assign axis_role_mem_read_data[i].last = 0;

        assign axis_role_mem_write_data[i].ready = 1'b0;
        //status
        assign axis_role_mem_read_status[i].valid = 1'b0;
        assign axis_role_mem_read_status[i].data = 0;

        assign axis_role_mem_write_status[i].valid = 1'b0;
        assign axis_role_mem_write_status[i].data = 0;
    end
end//for
endgenerate

   
endmodule
`default_nettype wire
