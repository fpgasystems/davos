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

module benchmark_controller
(
    //clk
    input  wire         pcie_clk,
    input  wire         pcie_aresetn,
    // user clk
    input wire          user_clk,
    input wire          user_aresetn,

    //Control interface
    axi_lite.slave      s_axil,    

    output reg          m_axis_ddr_bench_cmd_valid,
    input wire          m_axis_ddr_bench_cmd_ready,
    output reg[192:0]   m_axis_ddr_bench_cmd_data,
    output reg[1:0]     m_axis_ddr_bench_cmd_dest,


    output reg          m_axis_dma_bench_cmd_valid,
    input wire          m_axis_dma_bench_cmd_ready,
    output reg[192:0]   m_axis_dma_bench_cmd_data,

    output logic        m_axis_iperf_cmd_valid,
    input wire          m_axis_iperf_cmd_ready,
    output logic[127:0] m_axis_iperf_cmd_data,
    
    axis_meta.rmaster   m_axis_iperf_addr,
 

    //bench execution cycles
    input wire[63:0]    iperf_execution_cycles,
    input wire[47:0]    iperf_consumed_bytes,
    input wire[47:0]    iperf_produced_bytes,
    input wire[63:0]    ddr_bench_execution_cycles,
    input wire[63:0]    dma_bench_execution_cycles
    
);

localparam AXI_RESP_OK = 2'b00;
localparam AXI_RESP_SLVERR = 2'b10;

//TODO clean up and use enum

//WRITE states
localparam WRITE_IDLE = 0;
localparam WRITE_DATA = 1;
localparam WRITE_RESPONSE = 2;
localparam WRITE_IPERF     = 3;
localparam WRITE_IPERF_ADDR = 4;
localparam WRITE_DDR_BENCH = 5;
localparam WRITE_DMA_BENCH = 6;

//READ states
localparam READ_IDLE = 0;
//localparam READ_DATA = 1;
localparam READ_RESPONSE = 1;
localparam READ_RESPONSE2 = 2;
localparam WAIT_BRAM = 3;

//ADDRESES
localparam GPIO_REG_IPERF       = 8'h00;
localparam GPIO_REG_IPERF_ADDR  = 8'h01;
localparam GPIO_REG_DDR_BENCH   = 8'h02;
localparam GPIO_REG_DMA_BENCH   = 8'h03;
localparam GPIO_REG_BOARDNUM    = 8'h07;
localparam GPIO_REG_IPADDR      = 8'h08;
localparam GPIO_REG_IPERF_CONSUMED   = 8'h09;
localparam GPIO_REG_IPERF_PRODUCED  = 8'h0A;
//localparam GPIO_REG_DEBUG       = 8'h0C;
//localparam GPIO_REG_DEBUG2      = 8'h0D;
localparam GPIO_REG_IPERF_CYCLES     = 8'h0C;
localparam GPIO_REG_DDR_BENCH_CYCLES = 8'h0D;
localparam GPIO_REG_DMA_BENCH_CYCLES = 8'h0E;

reg user_aresetn_reg;
always @(posedge user_clk)
begin
    user_aresetn_reg <= user_aresetn;
end

// REGISTER SLICE

wire  [31:0] axil_awaddr;
wire         axil_awvalid;
reg          axil_awready;
wire  [31:0] axil_wdata;
wire   [3:0] axil_wstrb;
wire         axil_wvalid;
reg          axil_wready;
reg   [1:0]  axil_bresp;
reg          axil_bvalid;
wire         axil_bready;
wire  [31:0] axil_araddr;
wire         axil_arvalid;
reg          axil_arready;
reg  [31:0]  axil_rdata;
reg   [1:0]  axil_rresp;
reg          axil_rvalid;
wire         axil_rready;

axil_clock_converter axil_clock_converter (
  .s_axi_aclk(pcie_clk),                    // input wire aclk
  .s_axi_aresetn(pcie_aresetn),              // input wire aresetn
  .s_axi_awaddr(s_axil.awaddr),    // input wire [31 : 0] s_axi_awaddr
  .s_axi_awprot(3'b00),    // input wire [2 : 0] s_axi_awprot
  .s_axi_awvalid(s_axil.awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(s_axil.awready),  // output wire s_axi_awready
  .s_axi_wdata(s_axil.wdata),      // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(s_axil.wstrb),      // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(s_axil.wvalid),    // input wire s_axi_wvalid
  .s_axi_wready(s_axil.wready),    // output wire s_axi_wready
  .s_axi_bresp(s_axil.bresp),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(s_axil.bvalid),    // output wire s_axi_bvalid
  .s_axi_bready(s_axil.bready),    // input wire s_axi_bready
  .s_axi_araddr(s_axil.araddr),    // input wire [31 : 0] s_axi_araddr
  .s_axi_arprot(3'b00),    // input wire [2 : 0] s_axi_arprot
  .s_axi_arvalid(s_axil.arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(s_axil.arready),  // output wire s_axi_arready
  .s_axi_rdata(s_axil.rdata),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(s_axil.rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(s_axil.rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(s_axil.rready),    // input wire s_axi_rready

  .m_axi_aclk(user_clk),        // input wire m_axi_aclk
  .m_axi_aresetn(user_aresetn),  // input wire m_axi_aresetn
  .m_axi_awaddr(axil_awaddr),    // output wire [31 : 0] m_axi_awaddr
  .m_axi_awprot(),    // output wire [2 : 0] m_axi_awprot
  .m_axi_awvalid(axil_awvalid),  // output wire m_axi_awvalid
  .m_axi_awready(axil_awready),  // input wire m_axi_awready
  .m_axi_wdata(axil_wdata),      // output wire [31 : 0] m_axi_wdata
  .m_axi_wstrb(axil_wstrb),      // output wire [3 : 0] m_axi_wstrb
  .m_axi_wvalid(axil_wvalid),    // output wire m_axi_wvalid
  .m_axi_wready(axil_wready),    // input wire m_axi_wready
  .m_axi_bresp(axil_bresp),      // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(axil_bvalid),    // input wire m_axi_bvalid
  .m_axi_bready(axil_bready),    // output wire m_axi_bready
  .m_axi_araddr(axil_araddr),    // output wire [31 : 0] m_axi_araddr
  .m_axi_arprot(),    // output wire [2 : 0] m_axi_arprot
  .m_axi_arvalid(axil_arvalid),  // output wire m_axi_arvalid
  .m_axi_arready(axil_arready),  // input wire m_axi_arready
  .m_axi_rdata(axil_rdata),      // input wire [31 : 0] m_axi_rdata
  .m_axi_rresp(axil_rresp),      // input wire [1 : 0] m_axi_rresp
  .m_axi_rvalid(axil_rvalid),    // input wire m_axi_rvalid
  .m_axi_rready(axil_rready)    // output wire m_axi_rready
);

// ACTUAL LOGIC

reg[7:0] writeState;
reg[7:0] readState;

reg[31:0] writeAddr;
reg[31:0] readAddr;

reg[7:0] word_counter;


//handle writes
always @(posedge user_clk)
begin
    if (~user_aresetn) begin
        axil_awready <= 1'b0;
        axil_wready <= 1'b0;
        axil_bvalid <= 1'b0;

        m_axis_iperf_cmd_valid <= 1'b0;
        m_axis_iperf_addr.valid <= 1'b0;
        m_axis_ddr_bench_cmd_valid <= 1'b0;
        m_axis_dma_bench_cmd_valid <= 1'b0;
        
        word_counter <= 0;
        
        writeState <= WRITE_IDLE;
    end
    else begin
        case (writeState)
            WRITE_IDLE: begin
                axil_awready <= 1'b1;
                axil_wready <= 1'b0;
                axil_bvalid <= 1'b0;
                m_axis_dma_bench_cmd_valid <= 1'b0;
                
                writeAddr <= (axil_awaddr >> 5);
                if (axil_awvalid && axil_awready) begin
                    axil_awready <= 1'b0;
                    axil_wready <= 1'b1;
                    writeState <= WRITE_DATA;
                end
            end //WRITE_IDLE
            WRITE_DATA: begin
                axil_wready <= 1'b1;
                if (axil_wvalid && axil_wready) begin
                    axil_wready <= 0;
                    axil_bvalid <= 1'b1;
                    axil_bresp <= AXI_RESP_OK;
                    writeState <= WRITE_RESPONSE;
                    case (writeAddr)
                        GPIO_REG_IPERF: begin
                            word_counter <= word_counter + 1;
                            case (word_counter)
                                0: begin
                                    m_axis_iperf_cmd_data[31:0] <= axil_wdata;
                                end
                                1: begin
                                    m_axis_iperf_cmd_data[63:32] <= axil_wdata;
                                end
                                2: begin
                                    m_axis_iperf_cmd_data[95:64] <= axil_wdata;
                                end
                                3: begin
                                   m_axis_iperf_cmd_valid <= 1'b1;
                                   m_axis_iperf_cmd_data[127:96] <= axil_wdata;
                                   axil_bvalid <= 1'b0;
                                   word_counter <= 0;
                                   writeState <= WRITE_IPERF;
                                end
                             endcase
                        end
                        GPIO_REG_IPERF_ADDR: begin
                            word_counter <= word_counter +1;
                            case (word_counter)
                                0: begin
                                    m_axis_iperf_addr.dest <= axil_wdata;
                                end
                                1: begin
                                    m_axis_iperf_addr.valid <= 1'b1;
                                    m_axis_iperf_addr.data <= axil_wdata;
                                    axil_bvalid <= 1'b0;
                                    word_counter <= '0;
                                    writeState <= WRITE_IPERF_ADDR;
                                end
                            endcase
                        end
                        GPIO_REG_DDR_BENCH: begin
                            word_counter <= word_counter + 1;
                            case(word_counter)
                                0: begin //regBaseAddr[31:0]
                                    m_axis_ddr_bench_cmd_data[31:0] <= axil_wdata[31:0];
                                end
                                1: begin //regBaseAddr[47:32]
                                    m_axis_ddr_bench_cmd_data[47:32] <= axil_wdata[15:0];
                                end
                                2: begin //memoySize[31:0]
                                    m_axis_ddr_bench_cmd_data[79:48] <= axil_wdata[31:0];
                                end
                                3: begin //memorySize[47:32]
                                    m_axis_ddr_bench_cmd_data[95:80] <= axil_wdata[15:0];
                                end
                                4: begin //numberOfAccesses
                                    m_axis_ddr_bench_cmd_data[127:96] <= axil_wdata[31:0];
                                end
                                5: begin //chunkLength
                                    m_axis_ddr_bench_cmd_data[159:128] <= axil_wdata[31:0];
                                end
                                6: begin //strideLength
                                    m_axis_ddr_bench_cmd_data[191:160] <= axil_wdata[31:0];
                                end
                                7: begin
                                    m_axis_ddr_bench_cmd_data[192] <= axil_wdata[0];
                                    m_axis_ddr_bench_cmd_dest <= axil_wdata[2:1];
                                    axil_bvalid <= 1'b0;
                                    m_axis_ddr_bench_cmd_valid <= 1'b1;
                                    word_counter <= 0;
                                    writeState <= WRITE_DDR_BENCH;
                                end
                            endcase
                        end
                        GPIO_REG_DMA_BENCH: begin
                            word_counter <= word_counter + 1;
                            case(word_counter)
                                0: begin //regBaseAddr[31:0]
                                    m_axis_dma_bench_cmd_data[31:0] <= axil_wdata[31:0];
                                end
                                1: begin //regBaseAddr[47:32]
                                    m_axis_dma_bench_cmd_data[47:32] <= axil_wdata[15:0];
                                end
                                2: begin //memoySize[31:0]
                                    m_axis_dma_bench_cmd_data[79:48] <= axil_wdata[31:0];
                                end
                                3: begin //memorySize[47:32]
                                    m_axis_dma_bench_cmd_data[95:80] <= axil_wdata[15:0];
                                end
                                4: begin //numberOfAccesses
                                    m_axis_dma_bench_cmd_data[127:96] <= axil_wdata[31:0];
                                end
                                5: begin //chunkLength
                                    m_axis_dma_bench_cmd_data[159:128] <= axil_wdata[31:0];
                                end
                                6: begin //strideLength
                                    m_axis_dma_bench_cmd_data[191:160] <= axil_wdata[31:0];
                                end
                                7: begin
                                    m_axis_dma_bench_cmd_data[192] <= axil_wdata[0];
                                    axil_bvalid <= 1'b0;
                                    m_axis_dma_bench_cmd_valid <= 1'b1;
                                    word_counter <= 0;
                                    writeState <= WRITE_DMA_BENCH;
                                end
                            endcase
                        end
                    endcase
                end
            end //WRITE_DATA
            WRITE_RESPONSE: begin
                axil_bvalid <= 1'b1;
                if (axil_bvalid && axil_bready) begin
                    axil_bvalid <= 1'b0;
                    writeState <= WRITE_IDLE;
                end
            end//WRITE_RESPONSE
            WRITE_IPERF: begin
               m_axis_iperf_cmd_valid <= 1'b1;
               if (m_axis_iperf_cmd_valid && m_axis_iperf_cmd_ready) begin
                  axil_bvalid <= 1'b1;
                  axil_bresp <= AXI_RESP_OK;
                  m_axis_iperf_cmd_valid <= 1'b0;
                  writeState <= WRITE_RESPONSE;
               end
            end
            WRITE_IPERF_ADDR: begin
               m_axis_iperf_addr.valid <= 1'b1;
               if (m_axis_iperf_addr.valid && m_axis_iperf_addr.ready) begin
                  axil_bvalid <= 1'b1;
                  axil_bresp <= AXI_RESP_OK;
                  m_axis_iperf_addr.valid<= 1'b0;
                  writeState <= WRITE_RESPONSE;
               end
            end
            WRITE_DDR_BENCH: begin
                m_axis_ddr_bench_cmd_valid <= 1'b1;
                if (m_axis_ddr_bench_cmd_valid && m_axis_ddr_bench_cmd_ready) begin
                    axil_bvalid <= 1'b1;
                    axil_bresp <= AXI_RESP_OK;
                    m_axis_ddr_bench_cmd_valid <= 1'b0;
                    writeState <= WRITE_RESPONSE;
                end
            end
            WRITE_DMA_BENCH: begin
                m_axis_dma_bench_cmd_valid <= 1'b1;
                if (m_axis_dma_bench_cmd_valid && m_axis_dma_bench_cmd_ready) begin
                    axil_bvalid <= 1'b1;
                    axil_bresp <= AXI_RESP_OK;
                    m_axis_dma_bench_cmd_valid <= 1'b0;
                    writeState <= WRITE_RESPONSE;
                end
            end
        endcase
    end
end

//reads are currently not available
reg iperf_cycles_upper;
reg ddr_bench_cycles_upper;
reg dma_bench_cycles_upper;
always @(posedge user_clk)
begin
    if (~user_aresetn) begin
        axil_arready <= 1'b0;
        axil_rresp <= 0;
        axil_rvalid <= 1'b0;
        readState <= READ_IDLE;
        iperf_cycles_upper <= 0;
        ddr_bench_cycles_upper <= 0;
        dma_bench_cycles_upper <= 0;
    end
    else begin      
        case (readState)
            READ_IDLE: begin
                axil_arready <= 1'b1;
                if (axil_arready && axil_arvalid) begin
                    readAddr <= (axil_araddr >> 5);
                    axil_arready <= 1'b0;
                    readState <= READ_RESPONSE;
                end
            end
            READ_RESPONSE: begin
                axil_rvalid <= 1'b1;
                axil_rresp <= AXI_RESP_OK;
                case (readAddr)
                    GPIO_REG_IPERF_CYCLES: begin
                        if (!iperf_cycles_upper) begin
                            axil_rdata <= iperf_execution_cycles[31:0];
                        end
                        else begin
                            axil_rdata <= iperf_execution_cycles[63:32];
                        end
                    end
                    GPIO_REG_IPERF_CONSUMED: begin
                        axil_rdata <= iperf_consumed_bytes[31:0];
                    end
                    GPIO_REG_IPERF_PRODUCED: begin
                        axil_rdata <= iperf_produced_bytes[31:0];
                    end
                    GPIO_REG_DDR_BENCH_CYCLES: begin
                        if (!ddr_bench_cycles_upper) begin
                            axil_rdata <= ddr_bench_execution_cycles[31:0];
                        end
                        else begin
                            axil_rdata <= ddr_bench_execution_cycles[63:32];
                        end
                    end
                    GPIO_REG_DMA_BENCH_CYCLES: begin
                        if (!dma_bench_cycles_upper) begin
                            axil_rdata <= dma_bench_execution_cycles[31:0];
                        end
                        else begin
                            axil_rdata <= dma_bench_execution_cycles[63:32];
                        end
                    end
                    default: begin
                        axil_rresp <= AXI_RESP_SLVERR;
                        axil_rdata <= 32'hdeadbeef;
                    end
                endcase
                if (axil_rvalid && axil_rready) begin
                    axil_rvalid <= 1'b0;
                    if (readAddr == GPIO_REG_IPERF_CYCLES) begin
                        iperf_cycles_upper <= ~iperf_cycles_upper;
                    end
                    if (readAddr == GPIO_REG_DDR_BENCH_CYCLES) begin
                        ddr_bench_cycles_upper <= ~ddr_bench_cycles_upper;
                    end
                    if (readAddr == GPIO_REG_DMA_BENCH_CYCLES) begin
                        dma_bench_cycles_upper <= ~dma_bench_cycles_upper;
                    end
                    readState <= READ_IDLE;
                end
            end
        endcase
    end
end

endmodule
`default_nettype wire
