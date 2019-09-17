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

module mem_driver #(
    parameter ENABLE = 1,
    parameter C0_C_S_AXI_ID_WIDTH = 1,
    parameter C0_C_S_AXI_ADDR_WIDTH = 32,
    parameter C0_C_S_AXI_DATA_WIDTH = 512

)(
    //CLOCKS and reset
    input wire               c0_sys_clk_p,
    input wire               c0_sys_clk_n,
    input wire               sys_rst,

    /* I/O INTERFACE */
    output wire                  c0_ddr4_act_n,
    output wire[16:0]            c0_ddr4_adr,
    output wire[1:0]            c0_ddr4_ba,
    output wire[0:0]            c0_ddr4_bg,
    output wire[0:0]            c0_ddr4_cke,
    output wire[0:0]            c0_ddr4_odt,
    output wire[0:0]            c0_ddr4_cs_n,
    output wire[0:0]                 c0_ddr4_ck_t,
    output wire[0:0]                c0_ddr4_ck_c,
    output wire                 c0_ddr4_reset_n,
    inout  wire[8:0]            c0_ddr4_dm_dbi_n, //9:0 with native interface, 8:0 with Axi & ECC
    inout  wire[71:0]            c0_ddr4_dq, //79:0 with native interface, 71:0 with Axi & ECC
    inout  wire[8:0]            c0_ddr4_dqs_t, //9:0 with native interface, 8:0 with Axi & ECC
    inout  wire[8:0]            c0_ddr4_dqs_c, //9:0 with native interface, 8:0 with Axi & ECC
    //output wire                 c0_ui_clk,
    output wire                 c0_init_calib_complete,

    /* OS INTERFACE */
    output logic                mem_clk,
    output logic                mem_aresetn,
    // Slave Interface Write Address Ports
    input wire [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_awid,
    input wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s_axi_awaddr,
    input wire [7:0]                              s_axi_awlen,
    input wire [2:0]                              s_axi_awsize,
    input wire [1:0]                              s_axi_awburst,
    input wire [0:0]                              s_axi_awlock,
    input wire [3:0]                              s_axi_awcache,
    input wire [2:0]                              s_axi_awprot,
    input wire                                    s_axi_awvalid,
    output logic                                  s_axi_awready,
    // Slave Interface Write Data Ports
    input wire [C0_C_S_AXI_DATA_WIDTH-1:0]        s_axi_wdata,
    input wire [(C0_C_S_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb,
    input wire                                    s_axi_wlast,
    input wire                                    s_axi_wvalid,
    output logic                                    s_axi_wready,
    // Slave Interface Write Response Ports
    input wire                                    s_axi_bready,
    output logic [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_bid,
    output logic [1:0]                              s_axi_bresp,
    output logic                                    s_axi_bvalid,
    // Slave Interface Read Address Ports
    input wire [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_arid,
    input wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s_axi_araddr,
    input wire [7:0]                              s_axi_arlen,
    input wire [2:0]                              s_axi_arsize,
    input wire [1:0]                              s_axi_arburst,
    input wire [0:0]                              s_axi_arlock,
    input wire [3:0]                              s_axi_arcache,
    input wire [2:0]                              s_axi_arprot,
    input wire                                    s_axi_arvalid,
    output logic                                  s_axi_arready,
    // Slave Interface Read Data Ports
    input wire                                      s_axi_rready,
    output logic [C0_C_S_AXI_ID_WIDTH-1:0]          s_axi_rid,
    output logic [C0_C_S_AXI_DATA_WIDTH-1:0]        s_axi_rdata,
    output logic [1:0]                              s_axi_rresp,
    output logic                                    s_axi_rlast,
    output logic                                    s_axi_rvalid

    );


logic               c0_ui_clk;
logic               c0_ui_clk_sync_rst;
//logic               c0_mmcm_locked;
logic               c0_aresetn_r; 

always @(posedge c0_ui_clk)
    c0_aresetn_r <= ~c0_ui_clk_sync_rst;// & c0_mmcm_locked;

assign mem_clk = c0_ui_clk;
assign mem_aresetn = c0_aresetn_r;


generate
    if (ENABLE == 1) begin
ddr4_ip ddr4_inst (
  .c0_init_calib_complete(c0_init_calib_complete),          // output wire c0_init_calib_complete
  .dbg_clk(),                                        // output wire dbg_clk
  .c0_sys_clk_p(c0_sys_clk_p),                              // input wire c0_sys_clk_p
  .c0_sys_clk_n(c0_sys_clk_n),                              // input wire c0_sys_clk_n
  .dbg_bus(),                                        // output wire [511 : 0] dbg_bus
  .c0_ddr4_adr(c0_ddr4_adr),                                // output wire [16 : 0] c0_ddr4_adr
  .c0_ddr4_ba(c0_ddr4_ba),                                  // output wire [1 : 0] c0_ddr4_ba
  .c0_ddr4_cke(c0_ddr4_cke),                                // output wire [0 : 0] c0_ddr4_cke
  .c0_ddr4_cs_n(c0_ddr4_cs_n),                              // output wire [0 : 0] c0_ddr4_cs_n
  .c0_ddr4_dm_dbi_n(c0_ddr4_dm_dbi_n),                      // inout wire [8 : 0] c0_ddr4_dm_dbi_n
  .c0_ddr4_dq(c0_ddr4_dq),                                  // inout wire [71 : 0] c0_ddr4_dq
  .c0_ddr4_dqs_c(c0_ddr4_dqs_c),                            // inout wire [8 : 0] c0_ddr4_dqs_c
  .c0_ddr4_dqs_t(c0_ddr4_dqs_t),                            // inout wire [8 : 0] c0_ddr4_dqs_t
  .c0_ddr4_odt(c0_ddr4_odt),                                // output wire [0 : 0] c0_ddr4_odt
  .c0_ddr4_bg(c0_ddr4_bg),                                  // output wire [0 : 0] c0_ddr4_bg
  .c0_ddr4_reset_n(c0_ddr4_reset_n),                        // output wire c0_ddr4_reset_n
  .c0_ddr4_act_n(c0_ddr4_act_n),                            // output wire c0_ddr4_act_n
  .c0_ddr4_ck_c(c0_ddr4_ck_c),                              // output wire [0 : 0] c0_ddr4_ck_c
  .c0_ddr4_ck_t(c0_ddr4_ck_t),                              // output wire [0 : 0] c0_ddr4_ck_t
  .c0_ddr4_ui_clk(c0_ui_clk),                          // output wire c0_ddr4_ui_clk
  .c0_ddr4_ui_clk_sync_rst(c0_ui_clk_sync_rst),        // output wire c0_ddr4_ui_clk_sync_rst
  .c0_ddr4_aresetn(c0_aresetn_r),                        // input wire c0_ddr4_aresetn
  .c0_ddr4_s_axi_ctrl_awvalid(1'b0),  // input wire c0_ddr4_s_axi_ctrl_awvalid
  .c0_ddr4_s_axi_ctrl_awready(),  // output wire c0_ddr4_s_axi_ctrl_awready
  .c0_ddr4_s_axi_ctrl_awaddr(32'h0000_0000),    // input wire [31 : 0] c0_ddr4_s_axi_ctrl_awaddr
  .c0_ddr4_s_axi_ctrl_wvalid(1'b0),    // input wire c0_ddr4_s_axi_ctrl_wvalid
  .c0_ddr4_s_axi_ctrl_wready(),    // output wire c0_ddr4_s_axi_ctrl_wready
  .c0_ddr4_s_axi_ctrl_wdata(32'h0000_0000),      // input wire [31 : 0] c0_ddr4_s_axi_ctrl_wdata
  .c0_ddr4_s_axi_ctrl_bvalid(),    // output wire c0_ddr4_s_axi_ctrl_bvalid
  .c0_ddr4_s_axi_ctrl_bready(1'b1),    // input wire c0_ddr4_s_axi_ctrl_bready
  .c0_ddr4_s_axi_ctrl_bresp(),      // output wire [1 : 0] c0_ddr4_s_axi_ctrl_bresp
  .c0_ddr4_s_axi_ctrl_arvalid(1'b0),  // input wire c0_ddr4_s_axi_ctrl_arvalid
  .c0_ddr4_s_axi_ctrl_arready(),  // output wire c0_ddr4_s_axi_ctrl_arready
  .c0_ddr4_s_axi_ctrl_araddr(32'h0000_0000),    // input wire [31 : 0] c0_ddr4_s_axi_ctrl_araddr
  .c0_ddr4_s_axi_ctrl_rvalid(),    // output wire c0_ddr4_s_axi_ctrl_rvalid
  .c0_ddr4_s_axi_ctrl_rready(1'b1),    // input wire c0_ddr4_s_axi_ctrl_rready
  .c0_ddr4_s_axi_ctrl_rdata(),      // output wire [31 : 0] c0_ddr4_s_axi_ctrl_rdata
  .c0_ddr4_s_axi_ctrl_rresp(),      // output wire [1 : 0] c0_ddr4_s_axi_ctrl_rresp
  .c0_ddr4_interrupt(),                    // output wire c0_ddr4_interrupt
  .c0_ddr4_s_axi_awid(s_axi_awid),                  // input wire [3 : 0] c0_ddr4_s_axi_awid
  .c0_ddr4_s_axi_awaddr(s_axi_awaddr[30:0]),              // input wire [30 : 0] c0_ddr4_s_axi_awaddr
  .c0_ddr4_s_axi_awlen(s_axi_awlen),                // input wire [7 : 0] c0_ddr4_s_axi_awlen
  .c0_ddr4_s_axi_awsize(s_axi_awsize),              // input wire [2 : 0] c0_ddr4_s_axi_awsize
  .c0_ddr4_s_axi_awburst(s_axi_awburst),            // input wire [1 : 0] c0_ddr4_s_axi_awburst
  .c0_ddr4_s_axi_awlock(s_axi_awlock),              // input wire [0 : 0] c0_ddr4_s_axi_awlock
  .c0_ddr4_s_axi_awcache(s_axi_awcache),            // input wire [3 : 0] c0_ddr4_s_axi_awcache
  .c0_ddr4_s_axi_awprot(s_axi_awprot),              // input wire [2 : 0] c0_ddr4_s_axi_awprot
  .c0_ddr4_s_axi_awqos(0),                // input wire [3 : 0] c0_ddr4_s_axi_awqos
  .c0_ddr4_s_axi_awvalid(s_axi_awvalid),            // input wire c0_ddr4_s_axi_awvalid
  .c0_ddr4_s_axi_awready(s_axi_awready),            // output wire c0_ddr4_s_axi_awready
  .c0_ddr4_s_axi_wdata(s_axi_wdata),                // input wire [511 : 0] c0_ddr4_s_axi_wdata
  .c0_ddr4_s_axi_wstrb(s_axi_wstrb),                // input wire [63 : 0] c0_ddr4_s_axi_wstrb
  .c0_ddr4_s_axi_wlast(s_axi_wlast),                // input wire c0_ddr4_s_axi_wlast
  .c0_ddr4_s_axi_wvalid(s_axi_wvalid),              // input wire c0_ddr4_s_axi_wvalid
  .c0_ddr4_s_axi_wready(s_axi_wready),              // output wire c0_ddr4_s_axi_wready
  .c0_ddr4_s_axi_bready(s_axi_bready),              // input wire c0_ddr4_s_axi_bready
  .c0_ddr4_s_axi_bid(s_axi_bid),                    // output wire [3 : 0] c0_ddr4_s_axi_bid
  .c0_ddr4_s_axi_bresp(s_axi_bresp),                // output wire [1 : 0] c0_ddr4_s_axi_bresp
  .c0_ddr4_s_axi_bvalid(s_axi_bvalid),              // output wire c0_ddr4_s_axi_bvalid
  .c0_ddr4_s_axi_arid(s_axi_arid),                  // input wire [3 : 0] c0_ddr4_s_axi_arid
  .c0_ddr4_s_axi_araddr(s_axi_araddr[30:0]),              // input wire [30 : 0] c0_ddr4_s_axi_araddr
  .c0_ddr4_s_axi_arlen(s_axi_arlen),                // input wire [7 : 0] c0_ddr4_s_axi_arlen
  .c0_ddr4_s_axi_arsize(s_axi_arsize),              // input wire [2 : 0] c0_ddr4_s_axi_arsize
  .c0_ddr4_s_axi_arburst(s_axi_arburst),            // input wire [1 : 0] c0_ddr4_s_axi_arburst
  .c0_ddr4_s_axi_arlock(s_axi_arlock),              // input wire [0 : 0] c0_ddr4_s_axi_arlock
  .c0_ddr4_s_axi_arcache(s_axi_arcache),            // input wire [3 : 0] c0_ddr4_s_axi_arcache
  .c0_ddr4_s_axi_arprot(s_axi_arprot),              // input wire [2 : 0] c0_ddr4_s_axi_arprot
  .c0_ddr4_s_axi_arqos(0),                // input wire [3 : 0] c0_ddr4_s_axi_arqos
  .c0_ddr4_s_axi_arvalid(s_axi_arvalid),            // input wire c0_ddr4_s_axi_arvalid
  .c0_ddr4_s_axi_arready(s_axi_arready),            // output wire c0_ddr4_s_axi_arready
  .c0_ddr4_s_axi_rready(s_axi_rready),              // input wire c0_ddr4_s_axi_rready
  .c0_ddr4_s_axi_rlast(s_axi_rlast),                // output wire c0_ddr4_s_axi_rlast
  .c0_ddr4_s_axi_rvalid(s_axi_rvalid),              // output wire c0_ddr4_s_axi_rvalid
  .c0_ddr4_s_axi_rresp(s_axi_rresp),                // output wire [1 : 0] c0_ddr4_s_axi_rresp
  .c0_ddr4_s_axi_rid(s_axi_rid),                    // output wire [3 : 0] c0_ddr4_s_axi_rid
  .c0_ddr4_s_axi_rdata(s_axi_rdata),                // output wire [511 : 0] c0_ddr4_s_axi_rdata
  .sys_rst(sys_rst)                                        // input wire sys_rst
);
end
endgenerate

endmodule
`default_nettype wire
