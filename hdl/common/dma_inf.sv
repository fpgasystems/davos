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

module dma_inf(
    input wire          user_clk,
    input wire          user_aresetn,
    input wire          pcie_clk,
    input wire          pcie_aresetn,

    /* USER INTERFACE */
    //Commands
    axis_mem_cmd.slave  s_axis_dma_read_cmd,
    axis_mem_cmd.slave  s_axis_dma_write_cmd,

    //Data streams
    axi_stream.slave    s_axis_dma_write_data,
    axi_stream.master   m_axis_dma_read_data,

    /* DRIVER INTERFACE */
    //Control interface
    axi_lite.slave      s_axil,

    // AXI Stream Interface
    axi_stream.master   m_axis_c2h_data,
    axi_stream.slave    s_axis_h2c_data,

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
    input wire[7:0]     h2c_sts_0

);


/*
 * TLB wires
 */
wire axis_tlb_interface_valid;
wire axis_tlb_interface_ready;
wire[135:0] axis_tlb_interface_data;
wire axis_pcie_tlb_interface_valid;
wire axis_pcie_tlb_interface_ready;
wire[135:0] axis_pcie_tlb_interface_data;


wire        axis_dma_read_cmd_to_tlb_tvalid;
wire        axis_dma_read_cmd_to_tlb_tready;
wire[95:0]  axis_dma_read_cmd_to_tlb_tdata;
wire        axis_dma_write_cmd_to_tlb_tvalid;
wire        axis_dma_write_cmd_to_tlb_tready;
wire[95:0]  axis_dma_write_cmd_to_tlb_tdata;

wire        axis_dma_read_cmd_to_cc_tvalid;
wire        axis_dma_read_cmd_to_cc_tready;
wire[95:0]  axis_dma_read_cmd_to_cc_tdata;
wire        axis_dma_write_cmd_to_cc_tvalid;
wire        axis_dma_write_cmd_to_cc_tready;
wire[95:0]  axis_dma_write_cmd_to_cc_tdata;


wire        axis_dma_write_data_to_cc_tvalid;
wire        axis_dma_write_data_to_cc_tready;
wire[511:0] axis_dma_write_data_to_cc_tdata;
wire[63:0]  axis_dma_write_data_to_cc_tkeep;
wire        axis_dma_write_data_to_cc_tlast;

//PCIe clock
wire        axis_dma_read_data_to_cc_tvalid;
wire        axis_dma_read_data_to_cc_tready;
wire[511:0] axis_dma_read_data_to_cc_tdata;
wire[63:0]  axis_dma_read_data_to_cc_tkeep;
wire        axis_dma_read_data_to_cc_tlast;

/*
 * DMA wires
 */
wire        axis_dma_read_cmd_tvalid;
wire        axis_dma_read_cmd_tready;
wire[95:0]  axis_dma_read_cmd_tdata;

//wire[47:0] axis_dma_read_cmd_addr;
//assign axis_dma_read_cmd_addr = axis_dma_read_cmd_tdata[47:0];


wire        axis_dma_write_cmd_tvalid;
wire        axis_dma_write_cmd_tready;
wire[95:0]  axis_dma_write_cmd_tdata;

//wire[47:0] axis_dma_write_cmd_addr;
//assign axis_dma_write_cmd_addr = axis_dma_write_cmd_tdata[47:0];


wire        axis_dma_write_data_tvalid;
wire        axis_dma_write_data_tready;
wire[511:0] axis_dma_write_data_tdata;
wire[63:0]  axis_dma_write_data_tkeep;
wire        axis_dma_write_data_tlast;

//PCIe clock
wire        axis_dma_read_data_tvalid;
wire        axis_dma_read_data_tready;
wire[511:0] axis_dma_read_data_tdata;
wire[63:0]  axis_dma_read_data_tkeep;
wire        axis_dma_read_data_tlast;


/*
 * Memory Page Boundary Checks
 */
//get Base Addr of TLB for page boundary check
reg[47:0] regBaseVaddr;
reg[47:0] regBaseVaddrBoundCheck;
always @(posedge user_clk)
begin 
    if (~user_aresetn) begin
    end
    else begin
        if (axis_tlb_interface_valid && axis_tlb_interface_ready && axis_tlb_interface_data[128]) begin
            regBaseVaddr <= axis_tlb_interface_data[63:0];
            regBaseVaddrBoundCheck <= regBaseVaddr;
        end
    end
end


//TODO Currently supports at max one boundary crossing per command
mem_write_cmd_page_boundary_check_512_ip mem_write_cmd_page_boundary_check_inst (
  .regBaseVaddr_V(regBaseVaddrBoundCheck),          // input wire [63 : 0] regBaseVaddr_V
  .m_axis_cmd_V_TVALID(axis_dma_write_cmd_to_tlb_tvalid),    // output wire m_axis_cmd_TVALID
  .m_axis_cmd_V_TREADY(axis_dma_write_cmd_to_tlb_tready),    // input wire m_axis_cmd_TREADY
  .m_axis_cmd_V_TDATA(axis_dma_write_cmd_to_tlb_tdata),      // output wire [95 : 0] m_axis_cmd_TDATA
  .m_axis_data_TVALID(axis_dma_write_data_to_cc_tvalid),  // output wire m_axis_data_TVALID
  .m_axis_data_TREADY(axis_dma_write_data_to_cc_tready),  // input wire m_axis_data_TREADY
  .m_axis_data_TDATA(axis_dma_write_data_to_cc_tdata),    // output wire [63 : 0] m_axis_data_TDATA
  .m_axis_data_TKEEP(axis_dma_write_data_to_cc_tkeep),    // output wire [7 : 0] m_axis_data_TKEEP
  .m_axis_data_TLAST(axis_dma_write_data_to_cc_tlast),    // output wire [0 : 0] m_axis_data_TLAST
  .s_axis_cmd_V_TVALID(s_axis_dma_write_cmd.valid),    // input wire s_axis_cmd_TVALID
  .s_axis_cmd_V_TREADY(s_axis_dma_write_cmd.ready),    // output wire s_axis_cmd_TREADY
  .s_axis_cmd_V_TDATA({s_axis_dma_write_cmd.length, s_axis_dma_write_cmd.address}),      // input wire [95 : 0] s_axis_cmd_TDATA
  .s_axis_data_TVALID(s_axis_dma_write_data.valid),  // input wire s_axis_data_TVALID
  .s_axis_data_TREADY(s_axis_dma_write_data.ready),  // output wire s_axis_data_TREADY
  .s_axis_data_TDATA(s_axis_dma_write_data.data),    // input wire [63 : 0] s_axis_data_TDATA
  .s_axis_data_TKEEP(s_axis_dma_write_data.keep),    // input wire [7 : 0] s_axis_data_TKEEP
  .s_axis_data_TLAST(s_axis_dma_write_data.last),    // input wire [0 : 0] s_axis_data_TLAST
  .ap_clk(user_clk),                              // input wire aclk
  .ap_rst_n(user_aresetn)                        // input wire aresetn
);

//Boundary check for reads are done in the mem_read_cmd_merger_512
assign axis_dma_read_cmd_to_tlb_tvalid = s_axis_dma_read_cmd.valid;
assign s_axis_dma_read_cmd.ready = axis_dma_read_cmd_to_tlb_tready;
assign axis_dma_read_cmd_to_tlb_tdata = {s_axis_dma_read_cmd.length, s_axis_dma_read_cmd.address};

assign m_axis_dma_read_data.valid = axis_dma_read_data_to_cc_tvalid;
assign axis_dma_read_data_to_cc_tready = m_axis_dma_read_data.ready;
assign m_axis_dma_read_data.data = axis_dma_read_data_to_cc_tdata;
assign m_axis_dma_read_data.keep = axis_dma_read_data_to_cc_tkeep;
assign m_axis_dma_read_data.last = axis_dma_read_data_to_cc_tlast;

/*
 * Clock Conversion Data
 */

//TODO do not use FIFOs?
//axis_clock_converter_512 dma_bench_read_data_cc_inst (
axis_data_fifo_512_cc dma_bench_read_data_cc_inst (
  .s_axis_aresetn(pcie_aresetn),
  .s_axis_aclk(pcie_clk),
  .s_axis_tvalid(axis_dma_read_data_tvalid),
  .s_axis_tready(axis_dma_read_data_tready),
  .s_axis_tdata(axis_dma_read_data_tdata),
  .s_axis_tkeep(axis_dma_read_data_tkeep),
  .s_axis_tlast(axis_dma_read_data_tlast),

  .m_axis_aclk(user_clk),
  .m_axis_tvalid(axis_dma_read_data_to_cc_tvalid),
  .m_axis_tready(axis_dma_read_data_to_cc_tready),
  .m_axis_tdata(axis_dma_read_data_to_cc_tdata),
  .m_axis_tkeep(axis_dma_read_data_to_cc_tkeep),
  .m_axis_tlast(axis_dma_read_data_to_cc_tlast)
  
);
assign axis_dma_read_data_tvalid = s_axis_h2c_data.valid;
assign s_axis_h2c_data.ready = axis_dma_read_data_tready;
assign axis_dma_read_data_tdata = s_axis_h2c_data.data;
assign axis_dma_read_data_tkeep = s_axis_h2c_data.keep;
assign axis_dma_read_data_tlast = s_axis_h2c_data.last;

//axis_clock_converter_512 dma_bench_write_data_cc_inst (
axis_data_fifo_512_cc dma_bench_write_data_cc_inst (
  .s_axis_aresetn(user_aresetn),
  .s_axis_aclk(user_clk),
  .s_axis_tvalid(axis_dma_write_data_to_cc_tvalid),
  .s_axis_tready(axis_dma_write_data_to_cc_tready),
  .s_axis_tdata(axis_dma_write_data_to_cc_tdata),
  .s_axis_tkeep(axis_dma_write_data_to_cc_tkeep),
  .s_axis_tlast(axis_dma_write_data_to_cc_tlast),
  
  .m_axis_aclk(pcie_clk),
  .m_axis_tvalid(axis_dma_write_data_tvalid),
  .m_axis_tready(axis_dma_write_data_tready),
  .m_axis_tdata(axis_dma_write_data_tdata),
  .m_axis_tkeep(axis_dma_write_data_tkeep),
  .m_axis_tlast(axis_dma_write_data_tlast)
);

assign m_axis_c2h_data.valid = axis_dma_write_data_tvalid;
assign axis_dma_write_data_tready = m_axis_c2h_data.ready;
assign m_axis_c2h_data.data = axis_dma_write_data_tdata;
assign m_axis_c2h_data.keep = axis_dma_write_data_tkeep;
assign m_axis_c2h_data.last = axis_dma_write_data_tlast;

/*
 * TLB
 */
wire tlb_miss_count_valid;
wire[31:0] tlb_miss_count;
wire tlb_page_crossing_count_valid;
wire[31:0] tlb_page_crossing_count;

reg[31:0] tlb_miss_counter;
reg[31:0] tlb_boundary_crossing_counter;
reg[31:0] pcie_tlb_miss_counter;
reg[31:0] pcie_tlb_boundary_crossing_counter;

always @(posedge user_clk)
begin 
    if (~user_aresetn) begin
        tlb_miss_counter <= 0;
        tlb_boundary_crossing_counter <= 0;
    end
    else begin
        if (tlb_miss_count_valid) begin
            tlb_miss_counter <= tlb_miss_count;
        end
        if (tlb_page_crossing_count_valid) begin
            tlb_boundary_crossing_counter <= tlb_page_crossing_count;
        end
    end
end

axis_clock_converter_136 axis_tlb_if_clock_converter_inst (
   .s_axis_aresetn(pcie_aresetn),  // input wire s_axis_aresetn
   .s_axis_aclk(pcie_clk),        // input wire s_axis_aclk
   
   .s_axis_tvalid(axis_pcie_tlb_interface_valid),    // input wire s_axis_tvalid
   .s_axis_tready(axis_pcie_tlb_interface_ready),    // output wire s_axis_tready
   .s_axis_tdata(axis_pcie_tlb_interface_data),      // input wire [143 : 0] s_axis_tdata
   
   .m_axis_aclk(user_clk),        // input wire m_axis_aclk
   .m_axis_aresetn(user_aresetn),  // input wire m_axis_aresetn
     
   .m_axis_tvalid(axis_tlb_interface_valid),    // output wire m_axis_tvalid
   .m_axis_tready(axis_tlb_interface_ready),    // input wire m_axis_tready
   .m_axis_tdata(axis_tlb_interface_data)      // output wire [143 : 0] m_axis_tdata
);

axis_clock_converter_32 axis_clock_converter_tlb_miss (
   .s_axis_aresetn(user_aresetn),  // input wire s_axis_aresetn
   .s_axis_aclk(user_clk),        // input wire s_axis_aclk
   .s_axis_tvalid(1'b1),    // input wire s_axis_tvalid
   .s_axis_tready(),    // output wire s_axis_tready
   .s_axis_tdata(tlb_miss_counter),
   
   .m_axis_aclk(pcie_clk),        // input wire m_axis_aclk
   .m_axis_aresetn(pcie_aresetn),  // input wire m_axis_aresetn
   .m_axis_tvalid(),    // output wire m_axis_tvalid
   .m_axis_tready(1'b1),    // input wire m_axis_tready
   .m_axis_tdata(pcie_tlb_miss_counter)      // output wire [159 : 0] m_axis_tdata
);

axis_clock_converter_32 axis_clock_converter_tlb_page_crossing (
   .s_axis_aresetn(user_aresetn),  // input wire s_axis_aresetn
   .s_axis_aclk(user_clk),        // input wire s_axis_aclk
   .s_axis_tvalid(1'b1),    // input wire s_axis_tvalid
   .s_axis_tready(),    // output wire s_axis_tready
   .s_axis_tdata(tlb_boundary_crossing_counter),
   
   .m_axis_aclk(pcie_clk),        // input wire m_axis_aclk
   .m_axis_aresetn(pcie_aresetn),  // input wire m_axis_aresetn
   .m_axis_tvalid(),    // output wire m_axis_tvalid
   .m_axis_tready(1'b1),    // input wire m_axis_tready
   .m_axis_tdata(pcie_tlb_boundary_crossing_counter)      // output wire [159 : 0] m_axis_tdata
);

 tlb_ip tlb_inst (
   /*.m_axis_ddr_read_cmd_V_TVALID(axis_ddr_read_cmd_tvalid),    // output wire m_axis_ddr_read_cmd_tvalid
   .m_axis_ddr_read_cmd_V_TREADY(axis_ddr_read_cmd_tready),    // input wire m_axis_ddr_read_cmd_tready
   .m_axis_ddr_read_cmd_V_TDATA(axis_ddr_read_cmd_tdata),      // output wire [71 : 0] m_axis_ddr_read_cmd_tdata
   .m_axis_ddr_write_cmd_V_TVALID(axis_ddr_write_cmd_tvalid),  // output wire m_axis_ddr_write_cmd_tvalid
   .m_axis_ddr_write_cmd_V_TREADY(axis_ddr_write_cmd_tready),  // input wire m_axis_ddr_write_cmd_tready
   .m_axis_ddr_write_cmd_V_TDATA(axis_ddr_write_cmd_tdata),    // output wire [71 : 0] m_axis_ddr_write_cmd_tdata*/
   .m_axis_dma_read_cmd_V_TVALID(axis_dma_read_cmd_to_cc_tvalid),    // output wire m_axis_dma_read_cmd_tvalid
   .m_axis_dma_read_cmd_V_TREADY(axis_dma_read_cmd_to_cc_tready),    // input wire m_axis_dma_read_cmd_tready
   .m_axis_dma_read_cmd_V_TDATA(axis_dma_read_cmd_to_cc_tdata),      // output wire [95 : 0] m_axis_dma_read_cmd_tdata
   .m_axis_dma_write_cmd_V_TVALID(axis_dma_write_cmd_to_cc_tvalid),  // output wire m_axis_dma_write_cmd_tvalid
   .m_axis_dma_write_cmd_V_TREADY(axis_dma_write_cmd_to_cc_tready),  // input wire m_axis_dma_write_cmd_tready
   .m_axis_dma_write_cmd_V_TDATA(axis_dma_write_cmd_to_cc_tdata),    // output wire [95 : 0] m_axis_dma_write_cmd_tdata
   .s_axis_mem_read_cmd_V_TVALID(axis_dma_read_cmd_to_tlb_tvalid),    // input wire s_axis_mem_read_cmd_tvalid
   .s_axis_mem_read_cmd_V_TREADY(axis_dma_read_cmd_to_tlb_tready),    // output wire s_axis_mem_read_cmd_tready
   .s_axis_mem_read_cmd_V_TDATA(axis_dma_read_cmd_to_tlb_tdata),      // input wire [111 : 0] s_axis_mem_read_cmd_tdata
   .s_axis_mem_write_cmd_V_TVALID(axis_dma_write_cmd_to_tlb_tvalid),  // input wire s_axis_mem_write_cmd_tvalid
   .s_axis_mem_write_cmd_V_TREADY(axis_dma_write_cmd_to_tlb_tready),  // output wire s_axis_mem_write_cmd_tready
   .s_axis_mem_write_cmd_V_TDATA(axis_dma_write_cmd_to_tlb_tdata),    // input wire [111 : 0] s_axis_mem_write_cmd_tdata
   .s_axis_tlb_interface_V_TVALID(axis_tlb_interface_valid),  // input wire s_axis_tlb_interface_tvalid
   .s_axis_tlb_interface_V_TREADY(axis_tlb_interface_ready),  // output wire s_axis_tlb_interface_tready
   .s_axis_tlb_interface_V_TDATA(axis_tlb_interface_data),    // input wire [135 : 0] s_axis_tlb_interface_tdata
   .ap_clk(user_clk),                                                // input wire aclk
   .ap_rst_n(user_aresetn),                                          // input wire aresetn
   .regTlbMissCount_V(tlb_miss_count),                      // output wire [31 : 0] regTlbMissCount_V
   .regTlbMissCount_V_ap_vld(tlb_miss_count_valid),
   .regPageCrossingCount_V(tlb_page_crossing_count),                // output wire [31 : 0] regPageCrossingCount_V
   .regPageCrossingCount_V_ap_vld(tlb_page_crossing_count_valid)  // output wire regPageCrossingCount_V_ap_vld
 );

 /*
  * Clock Conversion Command
  */
axis_clock_converter_96 dma_bench_read_cmd_cc_inst (
  .s_axis_aresetn(user_aresetn),
  .s_axis_aclk(user_clk),
  .s_axis_tvalid(axis_dma_read_cmd_to_cc_tvalid),
  .s_axis_tready(axis_dma_read_cmd_to_cc_tready),
  .s_axis_tdata(axis_dma_read_cmd_to_cc_tdata),
  
  .m_axis_aresetn(pcie_aresetn),
  .m_axis_aclk(pcie_clk),
  .m_axis_tvalid(axis_dma_read_cmd_tvalid),
  .m_axis_tready(axis_dma_read_cmd_tready),
  .m_axis_tdata(axis_dma_read_cmd_tdata)
);

axis_clock_converter_96 dma_bench_write_cmd_cc_inst (
  .s_axis_aresetn(user_aresetn),
  .s_axis_aclk(user_clk),
  .s_axis_tvalid(axis_dma_write_cmd_to_cc_tvalid),
  .s_axis_tready(axis_dma_write_cmd_to_cc_tready),
  .s_axis_tdata(axis_dma_write_cmd_to_cc_tdata),
  
  .m_axis_aresetn(pcie_aresetn),
  .m_axis_aclk(pcie_clk),
  .m_axis_tvalid(axis_dma_write_cmd_tvalid),
  .m_axis_tready(axis_dma_write_cmd_tready),
  .m_axis_tdata(axis_dma_write_cmd_tdata)
);



/*
 * DMA Descriptor bypass
 */
wire      axis_dma_write_dsc_byp_ready;
reg       axis_dma_write_dsc_byp_load;
reg[63:0] axis_dma_write_dsc_byp_addr;
reg[31:0] axis_dma_write_dsc_byp_len;

wire      axis_dma_read_dsc_byp_ready;
reg       axis_dma_read_dsc_byp_load;
reg[63:0] axis_dma_read_dsc_byp_addr;
reg[31:0] axis_dma_read_dsc_byp_len;

// Write descriptor bypass
assign axis_dma_write_cmd_tready = axis_dma_write_dsc_byp_ready;
always @(posedge pcie_clk)
begin 
    if (~pcie_aresetn) begin
        axis_dma_write_dsc_byp_load <= 1'b0;
    end
    else begin
        axis_dma_write_dsc_byp_load <= 1'b0;
        
        if (axis_dma_write_cmd_tvalid && axis_dma_write_cmd_tready) begin
            axis_dma_write_dsc_byp_load <= 1'b1;
            axis_dma_write_dsc_byp_addr <= axis_dma_write_cmd_tdata[63:0];
            axis_dma_write_dsc_byp_len  <= axis_dma_write_cmd_tdata[95:64];
        end
    end
end

// Read descriptor bypass
assign axis_dma_read_cmd_tready = axis_dma_read_dsc_byp_ready;
always @(posedge pcie_clk)
begin 
    if (~pcie_aresetn) begin
        axis_dma_read_dsc_byp_load <= 1'b0;
    end
    else begin
        axis_dma_read_dsc_byp_load <= 1'b0;
        
        if (axis_dma_read_cmd_tvalid && axis_dma_read_cmd_tready) begin
            axis_dma_read_dsc_byp_load <= 1'b1;
            axis_dma_read_dsc_byp_addr <= axis_dma_read_cmd_tdata[63:0];
            axis_dma_read_dsc_byp_len  <= axis_dma_read_cmd_tdata[95:64];
        end
    end
end

//TODO use two engines
//TODO not necessary
//Assignments
assign c2h_dsc_byp_load_0 = axis_dma_write_dsc_byp_load;
assign axis_dma_write_dsc_byp_ready = c2h_dsc_byp_ready_0;
assign c2h_dsc_byp_addr_0 = axis_dma_write_dsc_byp_addr;
assign c2h_dsc_byp_len_0 = axis_dma_write_dsc_byp_len;


assign h2c_dsc_byp_load_0 = axis_dma_read_dsc_byp_load;
assign axis_dma_read_dsc_byp_ready = h2c_dsc_byp_ready_0;
assign h2c_dsc_byp_addr_0 = axis_dma_read_dsc_byp_addr;
assign h2c_dsc_byp_len_0 = axis_dma_read_dsc_byp_len;


/*
 * DMA Controller
 */
dma_controller controller_inst(
    .pcie_clk(pcie_clk),
    .pcie_aresetn(pcie_aresetn),
    .user_clk(pcie_clk), //TODO
    .user_aresetn(pcie_aresetn),
    
     // AXI Lite Master Interface connections
    .s_axil         (s_axil),
    
    // Control streams
    .m_axis_tlb_interface_valid        (axis_pcie_tlb_interface_valid),
    .m_axis_tlb_interface_ready        (axis_pcie_tlb_interface_ready),
    .m_axis_tlb_interface_data         (axis_pcie_tlb_interface_data),

    //tlb
    .tlb_miss_counter                   (pcie_tlb_miss_counter),
    .tlb_boundary_crossing_counter      (pcie_tlb_boundary_crossing_counter),
    //same clock
    .dma_write_cmd_counter              (dma_write_cmd_counter),
    .dma_write_word_counter             (dma_write_word_counter),
    .dma_write_pkg_counter              (dma_write_pkg_counter),
    .dma_read_cmd_counter               (dma_read_cmd_counter),
    .dma_read_word_counter              (dma_read_word_counter),
    .dma_read_pkg_counter               (dma_read_pkg_counter),

    //length counters
    .reset_dma_write_length_counter      (reset_dma_write_length_counter),
    .dma_write_length_counter            (dma_write_length_counter),
    .reset_dma_read_length_counter      (reset_dma_read_length_counter),
    .dma_read_length_counter            (dma_read_length_counter),
    .dma_reads_flushed                  (dma_reads_flushed)

);

/*
 * DMA Statistics
 */
reg[31:0] dma_write_cmd_counter;
reg[31:0] dma_write_load_counter;
reg[31:0] dma_write_word_counter;
reg[31:0] dma_write_pkg_counter;
wire reset_dma_write_length_counter;
reg[47:0] dma_write_length_counter;

reg[31:0] dma_read_cmd_counter;
reg[31:0] dma_read_load_counter;
reg[31:0] dma_read_word_counter;
reg[31:0] dma_read_pkg_counter;
wire reset_dma_read_length_counter;
reg[47:0] dma_read_length_counter;
reg dma_reads_flushed;

always @(posedge pcie_clk)
begin 
    if (~pcie_aresetn) begin
        dma_write_cmd_counter <= 0;
        dma_write_load_counter <= 0;
        dma_write_word_counter <= 0;
        dma_write_pkg_counter <= 0;

        dma_read_cmd_counter <= 0;
        dma_read_load_counter <= 0;
        dma_read_word_counter <= 0;
        dma_read_pkg_counter <= 0;

        //write_bypass_ready_counter <= 0;
        dma_write_length_counter <= 0;
        dma_read_length_counter <= 0;
        //dma_write_back_pressure_counter <= 0;
        dma_reads_flushed <= 0;
        //invalid_read <= 0;
    end
    else begin
        dma_reads_flushed <= (dma_read_cmd_counter == dma_read_pkg_counter);
        //write
        if (axis_dma_write_cmd_tvalid && axis_dma_write_cmd_tready) begin
            dma_write_cmd_counter <= dma_write_cmd_counter + 1;
            dma_write_length_counter <= dma_write_length_counter + axis_dma_write_cmd_tdata[95:64];
        end
        if (reset_dma_write_length_counter) begin
            dma_write_length_counter <= 0;
        end
        if (axis_dma_write_dsc_byp_load) begin
            dma_write_load_counter <= dma_write_load_counter + 1;
        end
        if (axis_dma_write_data_tvalid && axis_dma_write_data_tready) begin
            dma_write_word_counter <= dma_write_word_counter + 1;
            if (axis_dma_write_data_tlast) begin
                dma_write_pkg_counter <= dma_write_pkg_counter + 1;
            end
        end
        //read
        if (axis_dma_read_cmd_tvalid && axis_dma_read_cmd_tready) begin
            dma_read_cmd_counter <= dma_read_cmd_counter + 1;
            dma_read_length_counter <= dma_read_length_counter + axis_dma_read_cmd_tdata[95:64];
            /*if (axis_dma_read_cmd_tdata[95:64] == 0) begin
                invalid_read <=  1;
            end*/
        end
        if (reset_dma_read_length_counter) begin
            dma_read_length_counter <= 0;
        end
        if (axis_dma_read_dsc_byp_load) begin
            dma_read_load_counter <= dma_read_load_counter + 1;
        end
        if (axis_dma_read_data_tvalid && axis_dma_read_data_tready) begin
            dma_read_word_counter <= dma_read_word_counter + 1;
            if (axis_dma_read_data_tlast) begin
                dma_read_pkg_counter <= dma_read_pkg_counter + 1;
            end
        end
        /*if (axis_dma_write_cmd_tvalid && ~axis_dma_write_cmd_tready) begin
            dma_write_back_pressure_counter <= dma_write_back_pressure_counter + 1;
        end
        
        if (axis_dma_write_dsc_byp_ready) begin
            write_bypass_ready_counter <= 0;
        end
        else begin
            write_bypass_ready_counter <= write_bypass_ready_counter + 1;
        end*/
    end
end

endmodule
`default_nettype wire
