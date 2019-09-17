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

`include "davos_types.svh"


module axil_interconnect_done_right #(
    parameter NUM_MASTER_PORTS = 5
) (
    input wire      aclk,
    input wire      aresetn,

    axi_lite.slave      s_axil,
    axi_lite.master     m_axil[NUM_MASTER_PORTS]

);

//address write
wire [NUM_MASTER_PORTS*32-1:0]  axil_awaddr;
//wire [NUM_MASTER_PORTS*3-1:0]   axil_awprot;
wire [NUM_MASTER_PORTS-1:0]     axil_awvalid;
wire [NUM_MASTER_PORTS-1:0]     axil_awready;
 
//data write
wire [NUM_MASTER_PORTS*32-1:0]  axil_wdata;
wire [NUM_MASTER_PORTS*4-1:0]   axil_wstrb;
wire [NUM_MASTER_PORTS-1:0]     axil_wvalid;
wire [NUM_MASTER_PORTS-1:0]     axil_wready;
 
//write response (handhake)
wire [NUM_MASTER_PORTS*2-1:0]   axil_bresp;
wire [NUM_MASTER_PORTS-1:0]     axil_bvalid;
wire [NUM_MASTER_PORTS-1:0]     axil_bready;
 
//address read
wire [NUM_MASTER_PORTS*32-1:0]  axil_araddr;
//wire [NUM_MASTER_PORTS*3-1:0]   axil_arprot;
wire [NUM_MASTER_PORTS-1:0]     axil_arvalid;
wire [NUM_MASTER_PORTS-1:0]     axil_arready;
 
//data read
wire [NUM_MASTER_PORTS*32-1:0]  axil_rdata;
wire [NUM_MASTER_PORTS*2-1:0]   axil_rresp;
wire [NUM_MASTER_PORTS-1:0]     axil_rvalid;
wire [NUM_MASTER_PORTS-1:0]     axil_rready;


axil_controller_crossbar axi_interconnect_crossbar (
  .aclk(aclk),
  .aresetn(aresetn),
  .s_axi_awaddr(s_axil.awaddr),
  .s_axi_awprot({NUM_MASTER_PORTS{1'b0}}),
  .s_axi_awvalid(s_axil.awvalid),
  .s_axi_awready(s_axil.awready),
  .s_axi_wdata(s_axil.wdata),
  .s_axi_wstrb(s_axil.wstrb),
  .s_axi_wvalid(s_axil.wvalid),
  .s_axi_wready(s_axil.wready),
  .s_axi_bresp(s_axil.bresp),
  .s_axi_bvalid(s_axil.bvalid),
  .s_axi_bready(s_axil.bready),
  .s_axi_araddr(s_axil.araddr),
  .s_axi_arprot({NUM_MASTER_PORTS{1'b0}}),
  .s_axi_arvalid(s_axil.arvalid),
  .s_axi_arready(s_axil.arready),
  .s_axi_rdata(s_axil.rdata),
  .s_axi_rresp(s_axil.rresp),
  .s_axi_rvalid(s_axil.rvalid),
  .s_axi_rready(s_axil.rready),

  .m_axi_awaddr(axil_awaddr),
  .m_axi_awprot(),
  .m_axi_awvalid(axil_awvalid),
  .m_axi_awready(axil_awready),
  .m_axi_wdata(axil_wdata),
  .m_axi_wstrb(axil_wstrb),
  .m_axi_wvalid(axil_wvalid),
  .m_axi_wready(axil_wready),
  .m_axi_bresp(axil_bresp),
  .m_axi_bvalid(axil_bvalid),
  .m_axi_bready(axil_bready),
  .m_axi_araddr(axil_araddr),
  .m_axi_arprot(),
  .m_axi_arvalid(axil_arvalid),
  .m_axi_arready(axil_arready),
  .m_axi_rdata(axil_rdata),
  .m_axi_rresp(axil_rresp),
  .m_axi_rvalid(axil_rvalid),
  .m_axi_rready(axil_rready)
);


genvar idx;
generate
    for (idx=0; idx < NUM_MASTER_PORTS; idx=idx+1) begin
        assign m_axil[idx].awaddr   =    axil_awaddr[idx*32 +: 32];
        //assign m_axil[idx].awprot   =    axil_awprot[idx*3 +: 3];
        assign m_axil[idx].awvalid  =   axil_awvalid[idx];
        assign axil_awready[idx]    =   m_axil[idx].awready;
        assign m_axil[idx].wdata    =     axil_wdata[idx*32 +: 32];
        assign m_axil[idx].wstrb    =     axil_wstrb[idx*4 +: 4];
        assign m_axil[idx].wvalid   =    axil_wvalid[idx];
        assign axil_wready[idx]     =    m_axil[idx].wready;
        assign axil_bvalid[idx]     =    m_axil[idx].bvalid;
        assign axil_bresp[idx*2 +: 2]=    m_axil[idx].bresp;
        assign m_axil[idx].bready   =    axil_bready[idx];
        assign m_axil[idx].araddr   =    axil_araddr[idx*32 +: 32];
        //assign m_axil[idx].arprot   =    axil_arprot[idx*3 +: 3];
        assign m_axil[idx].arvalid  =   axil_arvalid[idx];
        assign axil_arready[idx]    =   m_axil[idx].arready;
        assign axil_rdata[idx*32 +: 32] =  m_axil[idx].rdata;
        assign axil_rresp[idx*2 +: 2]   =   m_axil[idx].rresp;
        assign axil_rvalid[idx]     =    m_axil[idx].rvalid;
        assign m_axil[idx].rready   =    axil_rready[idx];
    end
endgenerate
    
endmodule
`default_nettype wire
