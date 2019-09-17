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

module benchmark_role #(
    parameter NUM_ROLE_DDR_CHANNELS = 0
) (
    input wire      user_clk,
    input wire      user_aresetn,
    input wire      pcie_clk,
    input wire      pcie_aresetn,


    /* CONTROL INTERFACE */
    axi_lite.slave      s_axil,

    /* NETWORK  - TCP/IP INTERFACE */
    // open port for listening
    axis_meta.master    m_axis_listen_port,
    axis_meta.slave     s_axis_listen_port_status,
   
    axis_meta.master    m_axis_open_connection,
    axis_meta.slave     s_axis_open_status,
    axis_meta.master    m_axis_close_connection,

    axis_meta.slave     s_axis_notifications,
    axis_meta.master    m_axis_read_package,
    
    axis_meta.slave     s_axis_rx_metadata,
    axi_stream.slave    s_axis_rx_data,
    
    axis_meta.master    m_axis_tx_metadata,
    axi_stream.master   m_axis_tx_data,
    axis_meta.slave     s_axis_tx_status,
    
    /* NETWORK - UDP/IP INTERFACE */
    axis_meta.slave     s_axis_udp_rx_metadata,
    axi_stream.slave    s_axis_udp_rx_data,
    axis_meta.master    m_axis_udp_tx_metadata,
    axi_stream.master   m_axis_udp_tx_data,

    /* NETWORK - RDMA INTERFACE */
    axis_meta.slave             s_axis_roce_rx_read_cmd,
    axis_meta.slave             s_axis_roce_rx_write_cmd,
    axi_stream.slave            s_axis_roce_rx_write_data,
    axis_meta.master            m_axis_roce_tx_meta,
    axi_stream.master           m_axis_roce_tx_data,

    /* MEMORY INTERFACE */
    // read command
    axis_mem_cmd.master     m_axis_mem_read_cmd[NUM_DDR_CHANNELS],
    // read status
    axis_mem_status.slave   s_axis_mem_read_status[NUM_DDR_CHANNELS],
    // read data stream
    axi_stream.slave        s_axis_mem_read_data[NUM_DDR_CHANNELS],
    
    // write command
    axis_mem_cmd.master     m_axis_mem_write_cmd[NUM_DDR_CHANNELS],
    // write status
    axis_mem_status.slave   s_axis_mem_write_status[NUM_DDR_CHANNELS],
    // write data stream
    axi_stream.master       m_axis_mem_write_data[NUM_DDR_CHANNELS],
    
    /* DMA INTERFACE */
    axis_mem_cmd.master     m_axis_dma_read_cmd,
    axis_mem_cmd.master     m_axis_dma_write_cmd,

    axi_stream.slave        s_axis_dma_read_data,
    axi_stream.master       m_axis_dma_write_data

);

//Signals not used in role
//roce
assign s_axis_roce_rx_read_cmd.ready = 1'b1;
assign s_axis_roce_rx_write_cmd.ready = 1'b1;
assign s_axis_roce_rx_write_data.ready = 1'b1;
assign m_axis_roce_tx_meta.valid = 1'b0;
assign m_axis_roce_tx_data.valid = 1'b0;


/*
 * DMA Test Bench
 */
wire axis_dma_bench_cmd_valid;
reg axis_dma_bench_cmd_ready;
wire[192:0] axis_dma_bench_cmd_data;
 
wire execution_cycles_valid;
wire[63:0] execution_cycles_data;
reg[63:0] dma_bench_execution_cycles;
wire[63:0] pcie_dma_bench_execution_cycles;

reg[47:0] dmaBenchBaseAddr;
reg[47:0] dmaBenchMemorySize;
reg[31:0] dmaBenchNumberOfAccesses;
reg[31:0] dmaBenchChunkLength;
reg[31:0] dmaBenchStrideLength;
reg dmaBenchIsWrite;
reg dmaBenchStart;

reg[31:0] debug_cycle_counter;
reg runBench;

always @(posedge user_clk) begin
    if (~user_aresetn) begin
        axis_dma_bench_cmd_ready <= 0;
        runBench <= 0;
    end
    else begin
        dmaBenchStart <= 0;
        axis_dma_bench_cmd_ready <= 1;
        if (axis_dma_bench_cmd_valid && axis_dma_bench_cmd_ready) begin
            dmaBenchBaseAddr <= axis_dma_bench_cmd_data[47:0];
            dmaBenchMemorySize <= axis_dma_bench_cmd_data[95:48];
            dmaBenchNumberOfAccesses <= axis_dma_bench_cmd_data[127:96];
            dmaBenchChunkLength <= axis_dma_bench_cmd_data[159:128];
            dmaBenchStrideLength <= axis_dma_bench_cmd_data[191:160];
            dmaBenchIsWrite <= axis_dma_bench_cmd_data[192];
            dmaBenchStart <= 1;
            dma_bench_execution_cycles <= 0;
            debug_cycle_counter <= 0;
            runBench <= 1;
        end
        if (runBench) begin
            debug_cycle_counter <= debug_cycle_counter + 1;
        end
        if (execution_cycles_valid) begin
            dma_bench_execution_cycles <= execution_cycles_data;
            runBench <= 0;
        end
    end
end
 
dma_bench_ip dma_bench_inst(
 .m_axis_read_cmd_V_TVALID(m_axis_dma_read_cmd.valid),
 .m_axis_read_cmd_V_TREADY(m_axis_dma_read_cmd.ready),
 .m_axis_read_cmd_V_TDATA({m_axis_dma_read_cmd.length, m_axis_dma_read_cmd.address}),
 .m_axis_write_cmd_V_TVALID(m_axis_dma_write_cmd.valid),
 .m_axis_write_cmd_V_TREADY(m_axis_dma_write_cmd.ready),
 .m_axis_write_cmd_V_TDATA({m_axis_dma_write_cmd.length, m_axis_dma_write_cmd.address}),
 .m_axis_write_data_TVALID(m_axis_dma_write_data.valid),
 .m_axis_write_data_TREADY(m_axis_dma_write_data.ready),
 .m_axis_write_data_TDATA(m_axis_dma_write_data.data),
 .m_axis_write_data_TKEEP(m_axis_dma_write_data.keep),
 .m_axis_write_data_TLAST(m_axis_dma_write_data.last),
 .s_axis_read_data_TVALID(s_axis_dma_read_data.valid),
 .s_axis_read_data_TREADY(s_axis_dma_read_data.ready),
 .s_axis_read_data_TDATA(s_axis_dma_read_data.data),
 .s_axis_read_data_TKEEP(s_axis_dma_read_data.keep),
 .s_axis_read_data_TLAST(s_axis_dma_read_data.last),
 .ap_rst_n(user_aresetn),
 .ap_clk(user_clk),
 .regBaseAddr_V({16'h00, dmaBenchBaseAddr}),
 .memorySize_V({16'h00, dmaBenchMemorySize}),
 .numberOfAccesses_V(dmaBenchNumberOfAccesses),
 .chunkLength_V(dmaBenchChunkLength),
 .strideLength_V(dmaBenchStrideLength),
 .isWrite_V(dmaBenchIsWrite),
 .start_V(dmaBenchStart),
 .regExecutionCycles_V(execution_cycles_data),
 .regExecutionCycles_V_ap_vld(execution_cycles_valid)
 );




/*
 * Memory Benchmark
 */
wire axis_ddr_bench_cmd_valid;
reg axis_ddr_bench_cmd_ready;
wire[192:0] axis_ddr_bench_cmd_data;
wire[1:0]   axis_ddr_bench_cmd_dest;

wire ddr0_execution_cycles_valid;
wire[63:0] ddr0_execution_cycles_data;
wire ddr1_execution_cycles_valid;
wire[63:0] ddr1_execution_cycles_data;
reg[63:0] ddr_bench_execution_cycles;
wire[63:0] pcie_ddr_bench_execution_cycles;

reg[47:0] ddrBenchBaseAddr;
reg[47:0] ddrBenchMemorySize;
reg[31:0] ddrBenchNumberOfAccesses;
reg[31:0] ddrBenchChunkLength;
reg[31:0] ddrBenchStrideLength;
reg ddrBenchIsWrite;
(* mark_debug = "true" *)reg[1:0] ddrBenchStart;

(* mark_debug = "true" *)reg[31:0] ddr_debug_cycle_counter;
(* mark_debug = "true" *)reg ddrRunBench;

always @(posedge user_clk) begin
    if (~user_aresetn) begin
        axis_ddr_bench_cmd_ready <= 0;
        ddrRunBench <= 0;
        ddrBenchStart <= 0;
    end
    else begin
        ddrBenchStart <= 0;
        axis_ddr_bench_cmd_ready <= 1;
        if (axis_ddr_bench_cmd_valid && axis_ddr_bench_cmd_ready) begin
            ddrBenchBaseAddr <= axis_ddr_bench_cmd_data[47:0];
            ddrBenchMemorySize <= axis_ddr_bench_cmd_data[95:48];
            ddrBenchNumberOfAccesses <= axis_ddr_bench_cmd_data[127:96];
            ddrBenchChunkLength <= axis_ddr_bench_cmd_data[159:128];
            ddrBenchStrideLength <= axis_ddr_bench_cmd_data[191:160];
            ddrBenchIsWrite <= axis_ddr_bench_cmd_data[192];
            ddr_bench_execution_cycles <= 0;
            ddrRunBench <= 1;
            ddr_debug_cycle_counter <= 0;
            case (axis_ddr_bench_cmd_dest)
            0: ddrBenchStart[0] <= 1'b1;
            1: ddrBenchStart[1] <= 1'b1;
            endcase
        end
        if (ddrRunBench) begin
            ddr_debug_cycle_counter <= ddr_debug_cycle_counter + 1;
        end
        if (ddr0_execution_cycles_valid) begin
            ddr_bench_execution_cycles <= ddr0_execution_cycles_data;
            ddrRunBench <= 0;
        end
        if (ddr1_execution_cycles_valid) begin
            ddr_bench_execution_cycles <= ddr1_execution_cycles_data;
            ddrRunBench <= 0;
        end
    end
end

generate
if (NUM_ROLE_DDR_CHANNELS >= 1) begin
assign s_axis_mem_write_status[0].ready = 1'b1;
assign s_axis_mem_read_status[0].ready = 1'b1;

dma_bench_ip ddr0_bench_inst(
 .m_axis_read_cmd_V_TVALID(m_axis_mem_read_cmd[0].valid),
 .m_axis_read_cmd_V_TREADY(m_axis_mem_read_cmd[0].ready),
 .m_axis_read_cmd_V_TDATA({m_axis_mem_read_cmd[0].length, m_axis_mem_read_cmd[0].address}),
 .m_axis_write_cmd_V_TVALID(m_axis_mem_write_cmd[0].valid),
 .m_axis_write_cmd_V_TREADY(m_axis_mem_write_cmd[0].ready),
 .m_axis_write_cmd_V_TDATA({m_axis_mem_write_cmd[0].length, m_axis_mem_write_cmd[0].address}),
 .m_axis_write_data_TVALID(m_axis_mem_write_data[0].valid),
 .m_axis_write_data_TREADY(m_axis_mem_write_data[0].ready),
 .m_axis_write_data_TDATA(m_axis_mem_write_data[0].data),
 .m_axis_write_data_TKEEP(m_axis_mem_write_data[0].keep),
 .m_axis_write_data_TLAST(m_axis_mem_write_data[0].last),
 .s_axis_read_data_TVALID(s_axis_mem_read_data[0].valid),
 .s_axis_read_data_TREADY(s_axis_mem_read_data[0].ready),
 .s_axis_read_data_TDATA(s_axis_mem_read_data[0].data),
 .s_axis_read_data_TKEEP(s_axis_mem_read_data[0].keep),
 .s_axis_read_data_TLAST(s_axis_mem_read_data[0].last),
 .ap_rst_n(user_aresetn),
 .ap_clk(user_clk),
 .regBaseAddr_V({16'h00, ddrBenchBaseAddr}),
 .memorySize_V({16'h00, ddrBenchMemorySize}),
 .numberOfAccesses_V(ddrBenchNumberOfAccesses),
 .chunkLength_V(ddrBenchChunkLength),
 .strideLength_V(ddrBenchStrideLength),
 .isWrite_V(ddrBenchIsWrite),
 .start_V(ddrBenchStart[0]),
 .regExecutionCycles_V(ddr0_execution_cycles_data),
 .regExecutionCycles_V_ap_vld(ddr0_execution_cycles_valid)
 );
end
else begin
assign m_axis_mem_read_cmd[0].valid = 1'b0;
assign m_axis_mem_read_cmd[0].address = '0;
assign m_axis_mem_read_cmd[0].length = '0;
assign m_axis_mem_write_cmd[0].valid = 1'b0;
assign m_axis_mem_write_cmd[0].address = '0;
assign m_axis_mem_write_cmd[0].length = '0;

assign s_axis_mem_read_data[0].ready = 1'b1;
assign m_axis_mem_write_data[0].valid = 1'b0;
assign m_axis_mem_write_data[0].data = '0;
assign m_axis_mem_write_data[0].keep = '0;
assign m_axis_mem_write_data[0].last = 1'b0;


end
endgenerate

generate
if (NUM_ROLE_DDR_CHANNELS >= 2) begin
assign s_axis_mem_write_status[1].ready = 1'b1;
assign s_axis_mem_read_status[1].ready = 1'b1;

dma_bench_ip ddr1_bench_inst(
 .m_axis_read_cmd_V_TVALID(m_axis_mem_read_cmd[1].valid),
 .m_axis_read_cmd_V_TREADY(m_axis_mem_read_cmd[1].ready),
 .m_axis_read_cmd_V_TDATA({m_axis_mem_read_cmd[1].length, m_axis_mem_read_cmd[1].address}),
 .m_axis_write_cmd_V_TVALID(m_axis_mem_write_cmd[1].valid),
 .m_axis_write_cmd_V_TREADY(m_axis_mem_write_cmd[1].ready),
 .m_axis_write_cmd_V_TDATA({m_axis_mem_write_cmd[1].length, m_axis_mem_write_cmd[1].address}),
 .m_axis_write_data_TVALID(m_axis_mem_write_data[1].valid),
 .m_axis_write_data_TREADY(m_axis_mem_write_data[1].ready),
 .m_axis_write_data_TDATA(m_axis_mem_write_data[1].data),
 .m_axis_write_data_TKEEP(m_axis_mem_write_data[1].keep),
 .m_axis_write_data_TLAST(m_axis_mem_write_data[1].last),
 .s_axis_read_data_TVALID(s_axis_mem_read_data[1].valid),
 .s_axis_read_data_TREADY(s_axis_mem_read_data[1].ready),
 .s_axis_read_data_TDATA(s_axis_mem_read_data[1].data),
 .s_axis_read_data_TKEEP(s_axis_mem_read_data[1].keep),
 .s_axis_read_data_TLAST(s_axis_mem_read_data[1].last),
 .ap_rst_n(user_aresetn),
 .ap_clk(user_clk),
 .regBaseAddr_V({16'h00, ddrBenchBaseAddr}),
 .memorySize_V({16'h00, ddrBenchMemorySize}),
 .numberOfAccesses_V(ddrBenchNumberOfAccesses),
 .chunkLength_V(ddrBenchChunkLength),
 .strideLength_V(ddrBenchStrideLength),
 .isWrite_V(ddrBenchIsWrite),
 .start_V(ddrBenchStart[1]),
 .regExecutionCycles_V(ddr1_execution_cycles_data),
 .regExecutionCycles_V_ap_vld(ddr1_execution_cycles_valid)
 );
end
else begin
assign m_axis_mem_read_cmd[1].valid = 1'b0;
assign m_axis_mem_read_cmd[1].address = '0;
assign m_axis_mem_read_cmd[1].length = '0;
assign m_axis_mem_write_cmd[1].valid = 1'b0;
assign m_axis_mem_write_cmd[1].address = '0;
assign m_axis_mem_write_cmd[1].length = '0;

assign s_axis_mem_read_data[1].ready = 1'b1;
assign m_axis_mem_write_data[1].valid = 1'b0;
assign m_axis_mem_write_data[1].data = '0;
assign m_axis_mem_write_data[1].keep = '0;
assign m_axis_mem_write_data[1].last = 1'b0;
end
endgenerate

/*
 * TCP/IP Benchmark
 */
logic       axis_iperf_cmd_valid;
logic       axis_iperf_cmd_ready;
logic[127:0] axis_iperf_cmd_data;
axis_meta #(.WIDTH(32), .DEST_WIDTH(4))     axis_iperf_addr();

logic       runExperimentVio;
logic       runExperiment;
logic       dualMode;
logic[15:0] noOfConnections;
logic[7:0]  pkgWordCount;
logic[7:0]  packetGap;
logic[31:0] timeInSeconds;
logic[63:0] timeInCycles;

logic[7:0] listenCounter;
logic[15:0] openCounter;
logic[31:0] iperfAddresses [9:0];
logic[63:0] timer_cycles;
logic[63:0] iperf_execution_cycles;
logic running;


always @(posedge user_clk) begin
   if (~user_aresetn) begin
      runExperiment <= 1'b0;
      axis_iperf_cmd_ready <= 1'b0;
      axis_iperf_addr.ready <= 1'b0;
      iperfAddresses[0] <= 32'h0B01D40A;
      iperfAddresses[1] <= 32'h0B01D40A;
      iperfAddresses[2] <= 32'h0B01D40A;
      iperfAddresses[3] <= 32'h0B01D40A;
      iperfAddresses[4] <= 32'h0B01D40A;
      iperfAddresses[5] <= 32'h0B01D40A;
      iperfAddresses[6] <= 32'h0B01D40A;
      iperfAddresses[7] <= 32'h0B01D40A;
      iperfAddresses[8] <= 32'h0B01D40A;
      iperfAddresses[9] <= 32'h0B01D40A;
      running <= 1'b0;
            
      listenCounter <= '0;
      openCounter <= '0;
   end
   else begin
      runExperiment <= 1'b0;
      axis_iperf_cmd_ready <= 1'b1;
      axis_iperf_addr.ready <= 1'b1;
      if (axis_iperf_cmd_valid && axis_iperf_cmd_ready) begin
         runExperiment <= 1'b1;
         dualMode <= axis_iperf_cmd_data[0];
         noOfConnections <= {1'b0, axis_iperf_cmd_data[15:1]};
         pkgWordCount <= axis_iperf_cmd_data[23:16];
         packetGap <= axis_iperf_cmd_data[31:24];
         timeInSeconds <= axis_iperf_cmd_data[63:32];
         timeInCycles <= axis_iperf_cmd_data[127:64];
         timer_cycles <= '0;
         iperf_execution_cycles <= '0;
         running <= 1'b1;
      end
      if (runExperimentVio == 1'b1) begin
         runExperiment <= 1'b1;
         iperfAddresses[0] <= 32'h0B01D40A;
         dualMode <= 1'b0;//axis_iperf_cmd_data[0];
         noOfConnections <= 16'h01; //{1'b0, axis_iperf_cmd_data[15:1]};
         pkgWordCount <= 8'd175;//axis_iperf_cmd_data[23:16];
         packetGap <= 0;//axis_iperf_cmd_data[31:24];
         timeInSeconds <= 32'd10;//axis_iperf_cmd_data[63:32];
         timeInCycles <= 64'd1562500000;//axis_iperf_cmd_data[127:64];
         timer_cycles <= '0;
         iperf_execution_cycles <= '0;
         running <= 1'b1;
      end
      if (running) begin
        timer_cycles <= timer_cycles + 1;
      end
      if (axis_iperf_addr.valid && axis_iperf_addr.ready) begin
        iperfAddresses[axis_iperf_addr.dest] <= axis_iperf_addr.data;
      end
      if (m_axis_listen_port.valid && m_axis_listen_port.ready) begin
        listenCounter <= listenCounter +1;
      end
      if (m_axis_close_connection.valid && m_axis_close_connection.ready) begin
        running <= 1'b0;
        iperf_execution_cycles <= timer_cycles;
      end
      if (m_axis_open_connection.valid && m_axis_open_connection.ready) begin
        openCounter <= openCounter + 1;
      end
   end
end

vio_udp_iperf_client iperf_tcp_vio (
  .clk(user_clk),                // input wire clk
  .probe_out0(runExperimentVio)  // output wire [0 : 0] probe_out0
  //.probe_out1(regTargetIpAddress)  // output wire [31 : 0] probe_out1
);

iperf_client_ip iperf_client (
   .m_axis_close_connection_V_V_TVALID(m_axis_close_connection.valid),      // output wire m_axis_close_connection_TVALID
   .m_axis_close_connection_V_V_TREADY(m_axis_close_connection.ready),      // input wire m_axis_close_connection_TREADY
   .m_axis_close_connection_V_V_TDATA(m_axis_close_connection.data),        // output wire [15 : 0] m_axis_close_connection_TDATA
   .m_axis_listen_port_V_V_TVALID(m_axis_listen_port.valid),                // output wire m_axis_listen_port_TVALID
   .m_axis_listen_port_V_V_TREADY(m_axis_listen_port.ready),                // input wire m_axis_listen_port_TREADY
   .m_axis_listen_port_V_V_TDATA(m_axis_listen_port.data),                  // output wire [15 : 0] m_axis_listen_port_TDATA
   .m_axis_open_connection_V_TVALID(m_axis_open_connection.valid),        // output wire m_axis_open_connection_TVALID
   .m_axis_open_connection_V_TREADY(m_axis_open_connection.ready),        // input wire m_axis_open_connection_TREADY
   .m_axis_open_connection_V_TDATA(m_axis_open_connection.data),          // output wire [47 : 0] m_axis_open_connection_TDATA
   .m_axis_read_package_V_TVALID(m_axis_read_package.valid),              // output wire m_axis_read_package_TVALID
   .m_axis_read_package_V_TREADY(m_axis_read_package.ready),              // input wire m_axis_read_package_TREADY
   .m_axis_read_package_V_TDATA(m_axis_read_package.data),                // output wire [31 : 0] m_axis_read_package_TDATA
   .m_axis_tx_data_TVALID(m_axis_tx_data.valid),                        // output wire m_axis_tx_data_TVALID
   .m_axis_tx_data_TREADY(m_axis_tx_data.ready),                        // input wire m_axis_tx_data_TREADY
   .m_axis_tx_data_TDATA(m_axis_tx_data.data),                          // output wire [63 : 0] m_axis_tx_data_TDATA
   .m_axis_tx_data_TKEEP(m_axis_tx_data.keep),                          // output wire [7 : 0] m_axis_tx_data_TKEEP
   .m_axis_tx_data_TLAST(m_axis_tx_data.last),                          // output wire [0 : 0] m_axis_tx_data_TLAST
   .m_axis_tx_metadata_V_TVALID(m_axis_tx_metadata.valid),                // output wire m_axis_tx_metadata_TVALID
   .m_axis_tx_metadata_V_TREADY(m_axis_tx_metadata.ready),                // input wire m_axis_tx_metadata_TREADY
   .m_axis_tx_metadata_V_TDATA(m_axis_tx_metadata.data),                  // output wire [15 : 0] m_axis_tx_metadata_TDATA
   .s_axis_listen_port_status_V_TVALID(s_axis_listen_port_status.valid),  // input wire s_axis_listen_port_status_TVALID
   .s_axis_listen_port_status_V_TREADY(s_axis_listen_port_status.ready),  // output wire s_axis_listen_port_status_TREADY
   .s_axis_listen_port_status_V_TDATA(s_axis_listen_port_status.data),    // input wire [7 : 0] s_axis_listen_port_status_TDATA
   .s_axis_notifications_V_TVALID(s_axis_notifications.valid),            // input wire s_axis_notifications_TVALID
   .s_axis_notifications_V_TREADY(s_axis_notifications.ready),            // output wire s_axis_notifications_TREADY
   .s_axis_notifications_V_TDATA(s_axis_notifications.data),              // input wire [87 : 0] s_axis_notifications_TDATA
   .s_axis_open_status_V_TVALID(s_axis_open_status.valid),                // input wire s_axis_open_status_TVALID
   .s_axis_open_status_V_TREADY(s_axis_open_status.ready),                // output wire s_axis_open_status_TREADY
   .s_axis_open_status_V_TDATA(s_axis_open_status.data),                  // input wire [23 : 0] s_axis_open_status_TDATA
   .s_axis_rx_data_TVALID(s_axis_rx_data.valid),                        // input wire s_axis_rx_data_TVALID
   .s_axis_rx_data_TREADY(s_axis_rx_data.ready),                        // output wire s_axis_rx_data_TREADY
   .s_axis_rx_data_TDATA(s_axis_rx_data.data),                          // input wire [63 : 0] s_axis_rx_data_TDATA
   .s_axis_rx_data_TKEEP(s_axis_rx_data.keep),                          // input wire [7 : 0] s_axis_rx_data_TKEEP
   .s_axis_rx_data_TLAST(s_axis_rx_data.last),                          // input wire [0 : 0] s_axis_rx_data_TLAST
   .s_axis_rx_metadata_V_V_TVALID(s_axis_rx_metadata.valid),                // input wire s_axis_rx_metadata_TVALID
   .s_axis_rx_metadata_V_V_TREADY(s_axis_rx_metadata.ready),                // output wire s_axis_rx_metadata_TREADY
   .s_axis_rx_metadata_V_V_TDATA(s_axis_rx_metadata.data),                  // input wire [15 : 0] s_axis_rx_metadata_TDATA
   .s_axis_tx_status_V_TVALID(s_axis_tx_status.valid),                    // input wire s_axis_tx_status_TVALID
   .s_axis_tx_status_V_TREADY(s_axis_tx_status.ready),                    // output wire s_axis_tx_status_TREADY
   .s_axis_tx_status_V_TDATA(s_axis_tx_status.data),                      // input wire [23 : 0] s_axis_tx_status_TDATA
   
   //Client only
   .runExperiment_V(runExperiment),
   .dualModeEn_V(dualMode),                                          // input wire [0 : 0] dualModeEn_V
   .useConn_V(noOfConnections[13:0]),                                                // input wire [7 : 0] useConn_V
   .pkgWordCount_V(pkgWordCount),                                      // input wire [7 : 0] pkgWordCount_V
   .packetGap_V(packetGap),
   .timeInSeconds_V(timeInSeconds),
   .timeInCycles_V(timeInCycles),
   .regIpAddress0_V(iperfAddresses[0]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress1_V(iperfAddresses[1]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress2_V(iperfAddresses[2]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress3_V(iperfAddresses[3]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress4_V(iperfAddresses[4]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress5_V(iperfAddresses[5]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress6_V(iperfAddresses[6]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress7_V(iperfAddresses[7]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress8_V(iperfAddresses[8]),                                    // input wire [31 : 0] regIpAddress1_V
   .regIpAddress9_V(iperfAddresses[9]),                                    // input wire [31 : 0] regIpAddress1_V
   .ap_clk(user_clk),                                                          // input wire aclk
   .ap_rst_n(user_aresetn)                                                    // input wire aresetn
 );
 
 /*
  * UDP/IP Benchmark
  */
wire runUdpExperiment;
wire[31:0] regTargetIpAddress;

   
vio_udp_iperf_client iperf_udp_vio (
  .clk(user_clk),                // input wire clk
  .probe_out0(runUdpExperiment)  // output wire [0 : 0] probe_out0
  //.probe_out1(regTargetIpAddress)  // output wire [31 : 0] probe_out1
);
   
   reg runIperfUdp;
   reg[7:0] packetGapUdp;
    always @(posedge user_clk) begin
        if (~user_aresetn) begin
            runIperfUdp <= 0;
            packetGapUdp <= 0;
        end
        else begin
            runIperfUdp <= 0;
            /*if (button_north) begin
                packetGap <= 0;
                runIperfUdp <= 1;
            end
            if (button_center) begin
                packetGap <= 1;
                runIperfUdp <= 1;
            end
            if (button_south) begin
                packetGap <= 9;
                runIperfUdp <= 1;
            end*/
        end
  end
 
iperf_udp_ip iperf_udp_inst (
    .ap_clk(user_clk),                                            // input wire aclk
    .ap_rst_n(user_aresetn),                                      // input wire aresetn
    .runExperiment_V(runUdpExperiment),                      // input wire [0 : 0] runExperiment_V
    .pkgWordCount_V(10), //TODO
    .packetGap_V(packetGapUdp),
    //.regMyIpAddress_V(32'h02D4010B),                    // input wire [31 : 0] regMyIpAddress_V
  .targetIpAddress_V(iperfAddresses[0]),            // input wire [127 : 0] regTargetIpAddress_V
    
    .s_axis_rx_metadata_V_TVALID(s_axis_udp_rx_metadata.valid),
    .s_axis_rx_metadata_V_TREADY(s_axis_udp_rx_metadata.ready),
    .s_axis_rx_metadata_V_TDATA(s_axis_udp_rx_metadata.data),
    .s_axis_rx_data_TVALID(s_axis_udp_rx_data.valid),
    .s_axis_rx_data_TREADY(s_axis_udp_rx_data.ready),
    .s_axis_rx_data_TDATA(s_axis_udp_rx_data.data),
    .s_axis_rx_data_TKEEP(s_axis_udp_rx_data.keep),
    .s_axis_rx_data_TLAST(s_axis_udp_rx_data.last),
    
    .m_axis_tx_metadata_V_TVALID(m_axis_udp_tx_metadata.valid),
    .m_axis_tx_metadata_V_TREADY(m_axis_udp_tx_metadata.ready),
    .m_axis_tx_metadata_V_TDATA(m_axis_udp_tx_metadata.data),
    .m_axis_tx_data_TVALID(m_axis_udp_tx_data.valid),
    .m_axis_tx_data_TREADY(m_axis_udp_tx_data.ready),
    .m_axis_tx_data_TDATA(m_axis_udp_tx_data.data),
    .m_axis_tx_data_TKEEP(m_axis_udp_tx_data.keep),
    .m_axis_tx_data_TLAST(m_axis_udp_tx_data.last)
);  


/*
 * Role Controller
 */
benchmark_controller controller_inst(
    .pcie_clk(pcie_clk),
    .pcie_aresetn(pcie_aresetn),
    .user_clk(user_clk),
    .user_aresetn(user_aresetn),
    
     // AXI Lite Master Interface connections
    .s_axil         (s_axil),

    // Control streams
    .m_axis_iperf_cmd_valid             (axis_iperf_cmd_valid),
    .m_axis_iperf_cmd_ready             (axis_iperf_cmd_ready),
    .m_axis_iperf_cmd_data              (axis_iperf_cmd_data),
    .m_axis_iperf_addr                  (axis_iperf_addr),
    .m_axis_ddr_bench_cmd_valid         (axis_ddr_bench_cmd_valid),
    .m_axis_ddr_bench_cmd_ready         (axis_ddr_bench_cmd_ready),
    .m_axis_ddr_bench_cmd_data          (axis_ddr_bench_cmd_data),
    .m_axis_ddr_bench_cmd_dest          (axis_ddr_bench_cmd_dest),
    .m_axis_dma_bench_cmd_valid         (axis_dma_bench_cmd_valid),
    .m_axis_dma_bench_cmd_ready         (axis_dma_bench_cmd_ready),
    .m_axis_dma_bench_cmd_data          (axis_dma_bench_cmd_data),

    .iperf_execution_cycles             (iperf_execution_cycles),
    .iperf_consumed_bytes               (iperf_consumed),
    .iperf_produced_bytes               (iperf_produced),
    .ddr_bench_execution_cycles         (ddr_bench_execution_cycles),
    .dma_bench_execution_cycles         (dma_bench_execution_cycles)
    
);


/*
 * Statistics
 */

reg[47:0] iperf_consumed;
reg[47:0] iperf_produced;
always @(posedge user_clk) begin
    if (~user_aresetn) begin
        iperf_consumed <= '0;
        iperf_produced <= '0;
    end
    else begin
        if (s_axis_rx_data.valid && s_axis_rx_data.ready) begin
            case (s_axis_rx_data.keep)
                64'hFF: iperf_consumed <= iperf_consumed + 1;
                64'hFFFF: iperf_consumed <= iperf_consumed + 2;
                64'hFFFFFF: iperf_consumed <= iperf_consumed + 3;
                64'hFFFFFFFF: iperf_consumed <= iperf_consumed + 4;
                64'hFFFFFFFFFF: iperf_consumed <= iperf_consumed + 5;
                64'hFFFFFFFFFFFF: iperf_consumed <= iperf_consumed + 6;
                64'hFFFFFFFFFFFFFF: iperf_consumed <= iperf_consumed + 7;
                64'hFFFFFFFFFFFFFFFF: iperf_consumed <= iperf_consumed + 8;
            endcase
        end

        if (m_axis_tx_data.valid && m_axis_tx_data.ready) begin
            case (m_axis_tx_data.keep)
                64'hFF: iperf_produced <= iperf_produced + 1;
                64'hFFFF: iperf_produced <= iperf_produced + 2;
                64'hFFFFFF: iperf_produced <= iperf_produced + 3;
                64'hFFFFFFFF: iperf_produced <= iperf_produced + 4;
                64'hFFFFFFFFFF: iperf_produced <= iperf_produced + 5;
                64'hFFFFFFFFFFFF: iperf_produced <= iperf_produced + 6;
                64'hFFFFFFFFFFFFFF: iperf_produced <= iperf_produced + 7;
                64'hFFFFFFFFFFFFFFFF: iperf_produced <= iperf_produced + 8;
            endcase
        end

    end
end


logic[31:0] iperf_cmd_counter;
logic[31:0] iperf_pkg_counter;
logic[31:0] iperf_sts_counter;
logic[31:0] iperf_sts_good_counter;
always @(posedge user_clk) begin
    if (~user_aresetn) begin
        iperf_cmd_counter <= '0;
        iperf_pkg_counter <= '0;
        iperf_sts_counter <= '0;
        iperf_sts_good_counter <= '0;
    end
    else begin
        if (m_axis_tx_metadata.valid && m_axis_tx_metadata.ready) begin
            iperf_cmd_counter <= iperf_cmd_counter + 1;
        end
        if (m_axis_tx_data.valid && m_axis_tx_data.ready && m_axis_tx_data.last) begin
            iperf_pkg_counter <= iperf_pkg_counter + 1;
        end
        if (s_axis_tx_status.valid && s_axis_tx_status.ready) begin
            iperf_sts_counter <= iperf_sts_counter + 1;
            if (s_axis_tx_status.data[63:62] == 0) begin
                iperf_sts_good_counter <= iperf_sts_good_counter + 1;
            end
        end
    end
end

`ifdef DEBUG

ila_32_mixed benchmark_debug (
	.clk(user_clk), // input wire clk


	.probe0(s_axis_tx_status.valid), // input wire [0:0]  probe0  
	.probe1(s_axis_tx_status.ready), // input wire [0:0]  probe1 
	.probe2(m_axis_tx_data.last), // input wire [0:0]  probe2 
	.probe3(m_axis_tx_data.valid), // input wire [0:0]  probe3 
	.probe4(m_axis_tx_data.ready), // input wire [0:0]  probe4 
	.probe5(m_axis_tx_metadata.valid), // input wire [0:0]  probe5 
	.probe6(m_axis_tx_metadata.ready), // input wire [0:0]  probe6 
	.probe7(m_axis_read_package.valid), // input wire [0:0]  probe7 
	.probe8(m_axis_read_package.ready),
	.probe9(running),
	.probe10(m_axis_tx_metadata.data),
	.probe11(s_axis_udp_rx_metadata.valid),
	.probe12(s_axis_udp_rx_metadata.ready),
	.probe13(s_axis_udp_rx_data.ready),
	.probe14(s_axis_notifications.valid),
	.probe15(s_axis_notifications.ready),
	.probe16(s_axis_notifications.data[31:16]), // input wire [15:0]  probe8 
	.probe17(m_axis_tx_data.keep), // input wire [15:0]  probe9 
	.probe18(s_axis_tx_status.data[15:0]), // input wire [15:0]  probe10 
	.probe19(s_axis_tx_status.data[31:16]),// input wire [15:0]  probe11 
	.probe20(s_axis_tx_status.data[47:32]), // input wire [15:0]  probe12 
	.probe21(iperf_produced[15:0]), // input wire [15:0]  probe13 
	.probe22(iperf_produced[31:16]), // input wire [15:0]  probe14 
	.probe23(s_axis_tx_status.data[63:48]), // input wire [15:0]  probe15
	.probe24(timer_cycles[15:0]),
	.probe25(iperf_cmd_counter),
	.probe26(iperf_pkg_counter[15:0]),
	.probe27(iperf_pkg_counter[31:16]),
	.probe28(iperf_sts_counter[15:0]),
	.probe29(iperf_sts_counter[31:16]),
	.probe30(iperf_sts_good_counter[15:0]),
	.probe31(iperf_sts_good_counter[31:16])
);

`endif


endmodule
`default_nettype wire
