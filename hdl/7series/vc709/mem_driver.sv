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
    //input wire               clk156_25,
    //input wire               reset156_25_n,
    input wire clk212,
    input wire clk200,
    input wire sys_rst,
    
    //ddr3 pins
    //SODIMM 0
    // Inouts
    inout wire [63:0]                         c0_ddr3_dq,
    inout wire [7:0]                        c0_ddr3_dqs_n,
    inout wire [7:0]                        c0_ddr3_dqs_p,
    
    // output wires
    output logic [15:0]                     c0_ddr3_addr,
    output logic [2:0]                      c0_ddr3_ba,
    output logic                            c0_ddr3_ras_n,
    output logic                            c0_ddr3_cas_n,
    output logic                            c0_ddr3_we_n,
    output logic                            c0_ddr3_reset_n,
    output logic                       c0_ddr3_ck_p,
    output logic                       c0_ddr3_ck_n,
    output logic                       c0_ddr3_cke,
    output logic                       c0_ddr3_cs_n,
    output logic [7:0]                 c0_ddr3_dm,
    output logic                       c0_ddr3_odt,
    //output logic                       c0_ui_clk,
    output logic                       c0_init_calib_complete,
    
    //SODIMM 1
    // Inouts
    inout wire [63:0]                         c1_ddr3_dq,
    inout wire [7:0]                        c1_ddr3_dqs_n,
    inout wire [7:0]                        c1_ddr3_dqs_p,
    
    // output wires
    output logic [15:0]                     c1_ddr3_addr,
    output logic [2:0]                      c1_ddr3_ba,
    output logic                            c1_ddr3_ras_n,
    output logic                            c1_ddr3_cas_n,
    output logic                            c1_ddr3_we_n,
    output logic                            c1_ddr3_reset_n,
    output logic                        c1_ddr3_ck_p,
    output logic                        c1_ddr3_ck_n,
    output logic                        c1_ddr3_cke,
    output logic                        c1_ddr3_cs_n,
    output logic [7:0]                  c1_ddr3_dm,
    output logic                        c1_ddr3_odt,
    
    //ui output wires
    //output logic                        c1_ui_clk,
    output logic                        c1_init_calib_complete,

    /* OS INTERFACE */
    output logic                mem0_clk,
    output logic                mem0_aresetn,
    // Slave Interface Write Address Ports
    input wire [C0_C_S_AXI_ID_WIDTH-1:0]          s0_axi_awid,
    input wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s0_axi_awaddr,
    input wire [7:0]                              s0_axi_awlen,
    input wire [2:0]                              s0_axi_awsize,
    input wire [1:0]                              s0_axi_awburst,
    input wire [0:0]                              s0_axi_awlock,
    input wire [3:0]                              s0_axi_awcache,
    input wire [2:0]                              s0_axi_awprot,
    input wire                                    s0_axi_awvalid,
    output logic                                  s0_axi_awready,
    // Slave Interface Write Data Ports
    input wire [C0_C_S_AXI_DATA_WIDTH-1:0]        s0_axi_wdata,
    input wire [(C0_C_S_AXI_DATA_WIDTH/8)-1:0]    s0_axi_wstrb,
    input wire                                    s0_axi_wlast,
    input wire                                    s0_axi_wvalid,
    output logic                                    s0_axi_wready,
    // Slave Interface Write Response Ports
    input wire                                    s0_axi_bready,
    output logic [C0_C_S_AXI_ID_WIDTH-1:0]          s0_axi_bid,
    output logic [1:0]                              s0_axi_bresp,
    output logic                                    s0_axi_bvalid,
    // Slave Interface Read Address Ports
    input wire [C0_C_S_AXI_ID_WIDTH-1:0]          s0_axi_arid,
    input wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s0_axi_araddr,
    input wire [7:0]                              s0_axi_arlen,
    input wire [2:0]                              s0_axi_arsize,
    input wire [1:0]                              s0_axi_arburst,
    input wire [0:0]                              s0_axi_arlock,
    input wire [3:0]                              s0_axi_arcache,
    input wire [2:0]                              s0_axi_arprot,
    input wire                                    s0_axi_arvalid,
    output logic                                  s0_axi_arready,
    // Slave Interface Read Data Ports
    input wire                                  s0_axi_rready,
    output logic [C0_C_S_AXI_ID_WIDTH-1:0]          s0_axi_rid,
    output logic [C0_C_S_AXI_DATA_WIDTH-1:0]        s0_axi_rdata,
    output logic [1:0]                              s0_axi_rresp,
    output logic                                    s0_axi_rlast,
    output logic                                    s0_axi_rvalid,



    output logic                mem1_clk,
    output logic                mem1_aresetn,
    // Slave Interface Write Address Ports
    input wire [C0_C_S_AXI_ID_WIDTH-1:0]          s1_axi_awid,
    input wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s1_axi_awaddr,
    input wire [7:0]                              s1_axi_awlen,
    input wire [2:0]                              s1_axi_awsize,
    input wire [1:0]                              s1_axi_awburst,
    input wire [0:0]                              s1_axi_awlock,
    input wire [3:0]                              s1_axi_awcache,
    input wire [2:0]                              s1_axi_awprot,
    input wire                                    s1_axi_awvalid,
    output logic                                  s1_axi_awready,
    // Slave Interface Write Data Ports
    input wire [C0_C_S_AXI_DATA_WIDTH-1:0]        s1_axi_wdata,
    input wire [(C0_C_S_AXI_DATA_WIDTH/8)-1:0]    s1_axi_wstrb,
    input wire                                    s1_axi_wlast,
    input wire                                    s1_axi_wvalid,
    output logic                                    s1_axi_wready,
    // Slave Interface Write Response Ports
    input wire                                    s1_axi_bready,
    output logic [C0_C_S_AXI_ID_WIDTH-1:0]          s1_axi_bid,
    output logic [1:0]                              s1_axi_bresp,
    output logic                                    s1_axi_bvalid,
    // Slave Interface Read Address Ports
    input wire [C0_C_S_AXI_ID_WIDTH-1:0]          s1_axi_arid,
    input wire [C0_C_S_AXI_ADDR_WIDTH-1:0]        s1_axi_araddr,
    input wire [7:0]                              s1_axi_arlen,
    input wire [2:0]                              s1_axi_arsize,
    input wire [1:0]                              s1_axi_arburst,
    input wire [0:0]                              s1_axi_arlock,
    input wire [3:0]                              s1_axi_arcache,
    input wire [2:0]                              s1_axi_arprot,
    input wire                                    s1_axi_arvalid,
    output logic                                  s1_axi_arready,
    // Slave Interface Read Data Ports
    input wire                                  s1_axi_rready,
    output logic [C0_C_S_AXI_ID_WIDTH-1:0]          s1_axi_rid,
    output logic [C0_C_S_AXI_DATA_WIDTH-1:0]        s1_axi_rdata,
    output logic [1:0]                              s1_axi_rresp,
    output logic                                    s1_axi_rlast,
    output logic                                    s1_axi_rvalid
);


logic               c0_ui_clk;
logic               c0_ui_clk_sync_rst;
logic               c0_mmcm_locked;
logic               c0_aresetn_r; 
logic               c1_ui_clk;
logic               c1_ui_clk_sync_rst;
logic               c1_mmcm_locked;
logic               c1_aresetn_r; 

always @(posedge c0_ui_clk)
    c0_aresetn_r <= ~c0_ui_clk_sync_rst & c0_mmcm_locked;
    
always @(posedge c1_ui_clk)
    c1_aresetn_r <= ~c1_ui_clk_sync_rst & c1_mmcm_locked;

assign mem0_clk = c0_ui_clk;
assign mem0_aresetn = c0_aresetn_r;
assign mem1_clk = c1_ui_clk;
assign mem1_aresetn = c1_aresetn_r;


generate
    if (ENABLE == 1) begin
mig_axi_mm_dual u_mig_7series_0
(
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
    .c0_ddr3_dm(c0_ddr3_dm),
    .c0_ddr3_odt(c0_ddr3_odt),

 // Inputs
  // Single-ended system clock
    .c0_sys_clk_i(clk212),
  // Single-ended iodelayctrl clk (reference clock)
    .clk_ref_i(clk200),
    //.device_temp_i(12'd0),
     
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
    .c1_ddr3_dm(c1_ddr3_dm),
    .c1_ddr3_odt(c1_ddr3_odt),

  // Inputs
  // Single-ended system clock
    .c1_sys_clk_i(clk212),
  // System reset - Default polarity of sys_rst pin is Active Low.
  // System reset polarity will change based on the option 
  // selected in GUI.
    .sys_rst(sys_rst),
  
  // user interface signals
    .c0_ui_clk(c0_ui_clk),
    .c0_ui_clk_sync_rst(c0_ui_clk_sync_rst),
     
    .c0_mmcm_locked(c0_mmcm_locked),
    .c0_aresetn(c0_aresetn_r),
    .c0_app_sr_req                     (1'b0),
    .c0_app_ref_req                    (1'b0),
    .c0_app_zq_req                     (1'b0),
  
  // Slave Interface Write Address Ports
    .c0_s_axi_awid(s0_axi_awid),
    .c0_s_axi_awaddr(s0_axi_awaddr),
    .c0_s_axi_awlen(s0_axi_awlen),
    .c0_s_axi_awsize(s0_axi_awsize),
    .c0_s_axi_awburst(s0_axi_awburst),
    .c0_s_axi_awlock(2'b0),
    .c0_s_axi_awcache(4'b0),
    .c0_s_axi_awprot(3'b0),
    .c0_s_axi_awqos(4'b0),
    .c0_s_axi_awvalid(s0_axi_awvalid),
    .c0_s_axi_awready(s0_axi_awready),
  // Slave Interface Write Data Ports
    .c0_s_axi_wdata(s0_axi_wdata),
    .c0_s_axi_wstrb(s0_axi_wstrb),
    .c0_s_axi_wlast(s0_axi_wlast),
    .c0_s_axi_wvalid(s0_axi_wvalid),
    .c0_s_axi_wready(s0_axi_wready),
  // Slave Interface Write Response Ports
    .c0_s_axi_bready(s0_axi_bready),
    .c0_s_axi_bid(s0_axi_bid),
    .c0_s_axi_bresp(s0_axi_bresp),
    .c0_s_axi_bvalid(s0_axi_bvalid),
  // Slave Interface Read Address Ports
    .c0_s_axi_arid(s0_axi_arid),
    .c0_s_axi_araddr(s0_axi_araddr),
    .c0_s_axi_arlen(s0_axi_arlen),
    .c0_s_axi_arsize(s0_axi_arsize),
    .c0_s_axi_arburst(s0_axi_arburst),
    .c0_s_axi_arlock(2'b0),
    .c0_s_axi_arcache(4'b0),
    .c0_s_axi_arprot(3'b0),
    .c0_s_axi_arqos(4'h0),
    .c0_s_axi_arvalid(s0_axi_arvalid),
    .c0_s_axi_arready(s0_axi_arready),
  // Slave Interface Read Data Ports
    .c0_s_axi_rready(s0_axi_rready),
    .c0_s_axi_rid(s0_axi_rid),
    .c0_s_axi_rdata(s0_axi_rdata),
    .c0_s_axi_rresp(s0_axi_rresp),
    .c0_s_axi_rlast(s0_axi_rlast),
    .c0_s_axi_rvalid(s0_axi_rvalid),
    .c0_init_calib_complete(c0_init_calib_complete),
     
  // user interface signals
    .c1_ui_clk(c1_ui_clk),
    .c1_ui_clk_sync_rst(c1_ui_clk_sync_rst),
    .c1_mmcm_locked(c1_mmcm_locked),
    .c1_aresetn(c1_aresetn_r),
    .c1_app_sr_req                     (1'b0),
    .c1_app_ref_req                    (1'b0),
    .c1_app_zq_req                     (1'b0),
          
  // Slave Interface Write Address Ports
    .c1_s_axi_awid(s1_axi_awid),
    .c1_s_axi_awaddr(s1_axi_awaddr),
    .c1_s_axi_awlen(s1_axi_awlen),
    .c1_s_axi_awsize(s1_axi_awsize),
    .c1_s_axi_awburst(s1_axi_awburst),
    .c1_s_axi_awlock(2'b0),
    .c1_s_axi_awcache(4'b0),
    .c1_s_axi_awprot(3'b0),
    .c1_s_axi_awqos(4'b0),
    .c1_s_axi_awvalid(s1_axi_awvalid),
    .c1_s_axi_awready(s1_axi_awready),
  // Slave Interface Write Data Ports
    .c1_s_axi_wdata(s1_axi_wdata),
    .c1_s_axi_wstrb(s1_axi_wstrb),
    .c1_s_axi_wlast(s1_axi_wlast),
    .c1_s_axi_wvalid(s1_axi_wvalid),
    .c1_s_axi_wready(s1_axi_wready),
  // Slave Interface Write Response Ports
    .c1_s_axi_bready(s1_axi_bready),
    .c1_s_axi_bid(s1_axi_bid),
    .c1_s_axi_bresp(s1_axi_bresp),
    .c1_s_axi_bvalid(s1_axi_bvalid),
  // Slave Interface Read Address Ports
    .c1_s_axi_arid(s1_axi_arid),
    .c1_s_axi_araddr(s1_axi_araddr),
    .c1_s_axi_arlen(s1_axi_arlen),
    .c1_s_axi_arsize(s1_axi_arsize),
    .c1_s_axi_arburst(s1_axi_arburst),
    .c1_s_axi_arlock(2'b0),
    .c1_s_axi_arcache(4'b0),
    .c1_s_axi_arprot(3'b0),
    .c1_s_axi_arqos(4'h0),
    .c1_s_axi_arvalid(s1_axi_arvalid),
    .c1_s_axi_arready(s1_axi_arready),
  // Slave Interface Read Data Ports
    .c1_s_axi_rready(s1_axi_rready),
    .c1_s_axi_rid(s1_axi_rid),
    .c1_s_axi_rdata(s1_axi_rdata),
    .c1_s_axi_rresp(s1_axi_rresp),
    .c1_s_axi_rlast(s1_axi_rlast),
    .c1_s_axi_rvalid(s1_axi_rvalid),
    .c1_init_calib_complete(c1_init_calib_complete)
);
end
endgenerate

endmodule
`default_nettype wire