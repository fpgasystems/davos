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

module dma_controller
(
    //clk
    input  wire         pcie_clk,
    input  wire         pcie_aresetn,
    // user clk
    input wire          user_clk,
    input wire          user_aresetn,

    // Control Interface
    axi_lite.slave      s_axil,
    
    // TLB command
    output reg         m_axis_tlb_interface_valid,
    input wire         m_axis_tlb_interface_ready,
    output reg[135:0]  m_axis_tlb_interface_data,

    //tlb on same clock
    input wire[31:0]    tlb_miss_counter,
    input wire[31:0]    tlb_boundary_crossing_counter,

    //same clock
    input wire[31:0]    dma_write_cmd_counter,
    input wire[31:0]    dma_write_word_counter,
    input wire[31:0]    dma_write_pkg_counter,
    input wire[31:0]    dma_read_cmd_counter,
    input wire[31:0]    dma_read_word_counter,
    input wire[31:0]    dma_read_pkg_counter,
    output reg          reset_dma_write_length_counter,
    input wire[47:0]    dma_write_length_counter,
    output reg          reset_dma_read_length_counter,
    input wire[47:0]    dma_read_length_counter,
    input wire          dma_reads_flushed

);

localparam AXI_RESP_OK = 2'b00;
localparam AXI_RESP_SLVERR = 2'b10;


//WRITE states
localparam WRITE_IDLE = 0;
localparam WRITE_DATA = 1;
localparam WRITE_RESPONSE = 2;
localparam WRITE_TLB = 5;
localparam WRITE_DMA_BENCH = 6;

//READ states
localparam READ_IDLE = 0;
//localparam READ_DATA = 1;
localparam READ_RESPONSE = 1;
localparam READ_RESPONSE2 = 2;
localparam WAIT_BRAM = 3;

//ADDRESES
localparam GPIO_REG_TLB         = 8'h02;
localparam GPIO_REG_DMA_BENCH   = 8'h03;
localparam GPIO_REG_BOARDNUM    = 8'h07;
localparam GPIO_REG_IPADDR      = 8'h08;
localparam GPIO_REG_DMA_READS   = 8'h0A;
localparam GPIO_REG_DMA_WRITES  = 8'h0B;
//localparam GPIO_REG_DEBUG       = 8'h0C;
localparam GPIO_REG_DEBUG2      = 8'h0D;
//localparam GPIO_REG_DMA_BENCH_CYCLES = 8'h0E;

localparam NUM_DMA_DEBUG_REGS = 10;

localparam DEBUG_WRITE_CMD  = 8'h00;
localparam DEBUG_WRITE_WORD = 8'h01;
localparam DEBUG_WRITE_PKG  = 8'h02;
localparam DEBUG_WRITE_LEN  = 8'h03;
localparam DEBUG_READ_CMD   = 8'h04;
localparam DEBUG_READ_WORD  = 8'h05;
localparam DEBUG_READ_PKG   = 8'h06;
localparam DEBUG_READ_LEN   = 8'h07;
localparam DEBUG_TLB_MISS   = 8'h08;
localparam DEBUG_TLB_PAGE_CROSS = 8'h09;


/*reg net_aresetn_reg;
always @(posedge net_aclk)
begin
    net_aresetn_reg <= net_aresetn;
end*/

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

axi_register_slice axil_register_slice (
  .aclk(pcie_clk),                    // input wire aclk
  .aresetn(pcie_aresetn),              // input wire aresetn
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
  //.m_axi_aclk(user_clk),        // input wire m_axi_aclk
  //.m_axi_aresetn(user_aresetn),  // input wire m_axi_aresetn
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
        
        m_axis_tlb_interface_valid <= 1'b0;
        word_counter <= 0;
        
        writeState <= WRITE_IDLE;
    end
    else begin
        case (writeState)
            WRITE_IDLE: begin
                axil_awready <= 1'b1;
                axil_wready <= 1'b0;
                axil_bvalid <= 1'b0;
                m_axis_tlb_interface_valid <= 1'b0;
                
                reset_dma_write_length_counter <= 1'b0;
                reset_dma_read_length_counter <= 1'b0;
                
                writeAddr <= (axil_awaddr[11:0] >> 5);
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
                        GPIO_REG_TLB: begin
                            word_counter <= word_counter + 1;
                            case(word_counter)
                                0: begin
                                    m_axis_tlb_interface_data[31:0] <= axil_wdata[31:0];
                                end
                                1: begin
                                    m_axis_tlb_interface_data[63:32] <= axil_wdata[31:0];
                                end
                                2: begin
                                    m_axis_tlb_interface_data[95:64] <= axil_wdata[31:0];
                                end
                                3: begin
                                    m_axis_tlb_interface_data[127:96] <= axil_wdata[31:0];
                                end
                                4: begin
                                    m_axis_tlb_interface_data[128] <= axil_wdata[0:0];
                                    axil_bvalid <= 1'b0;
                                    m_axis_tlb_interface_valid <= 1'b1;
                                    word_counter <= 0;
                                    writeState <= WRITE_TLB;
                                end
                            endcase
                        end
                        GPIO_REG_DMA_READS: begin
                            reset_dma_read_length_counter <= 1'b1;
                            axil_bvalid <= 1'b1;
                            axil_bresp <= AXI_RESP_OK;
                            writeState <= WRITE_RESPONSE;
                        end
                        GPIO_REG_DMA_WRITES: begin
                            reset_dma_write_length_counter <= 1'b1;
                            axil_bvalid <= 1'b1;
                            axil_bresp <= AXI_RESP_OK;
                            writeState <= WRITE_RESPONSE;
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
            WRITE_TLB: begin
                m_axis_tlb_interface_valid <= 1'b1;
                if (m_axis_tlb_interface_valid && m_axis_tlb_interface_ready) begin
                    axil_bvalid <= 1'b1;
                    axil_bresp <= AXI_RESP_OK;
                    m_axis_tlb_interface_valid <= 1'b0;
                    writeState <= WRITE_RESPONSE;
                end
            end
        endcase
    end
end

//reads are currently not available
reg[7:0] debugRegAddr;
reg dma_read_length_upper;
reg dma_write_length_upper;
always @(posedge user_clk)
begin
    if (~user_aresetn) begin
        axil_arready <= 1'b0;
        axil_rresp <= 0;
        axil_rvalid <= 1'b0;
        //read_en <= 0;
        readState <= READ_IDLE;
        //read_addr <= 0;
        debugRegAddr <= 0;
        dma_read_length_upper <= 0;
        dma_write_length_upper <= 0;
    end
    else begin      
        case (readState)
            READ_IDLE: begin
                axil_arready <= 1'b1;
                //read_en <= 1;
                if (axil_arready && axil_arvalid) begin
                    readAddr <= (axil_araddr[11:0] >> 5);
                    axil_arready <= 1'b0;
                    readState <= READ_RESPONSE;
                end
                /*if (read_addr == NUM_DEBUG_REGS) begin
                    read_addr <= 0;
                end*/
                if (debugRegAddr == NUM_DMA_DEBUG_REGS) begin
                    debugRegAddr <= 0;
                end
            end
            READ_RESPONSE: begin
                axil_rvalid <= 1'b1;
                axil_rresp <= AXI_RESP_OK;
                case (readAddr)
                    GPIO_REG_DMA_READS: begin
                        if (dma_reads_flushed) begin
                            if (!dma_read_length_upper) begin
                                axil_rdata <= dma_read_length_counter[31:0];
                            end
                            else begin
                                axil_rdata[15:0] <= dma_read_length_counter[47:32];
                                axil_rdata[31:16] <= 0;
                            end
                        end
                        else begin
                            axil_rdata <= 0;
                        end
                    end
                    GPIO_REG_DMA_WRITES: begin
                        if (!dma_write_length_upper) begin
                            axil_rdata <= dma_write_length_counter[31:0];
                        end
                        else begin
                            axil_rdata[15:0] <= dma_write_length_counter[47:32];
                            axil_rdata[31:16] <= 0;
                        end
                    end
                    /*GPIO_REG_DEBUG: begin
                        axil_rdata <= read_data;
                    end*/
                    GPIO_REG_DEBUG2: begin
                        case (debugRegAddr)
                            DEBUG_WRITE_CMD: begin
                                 axil_rdata <= dma_write_cmd_counter;
                            end
                            DEBUG_WRITE_WORD: begin
                                 axil_rdata <= dma_write_word_counter;
                            end
                            DEBUG_WRITE_PKG: begin
                                 axil_rdata <= dma_write_pkg_counter;
                            end
                            DEBUG_WRITE_LEN: begin
                                axil_rdata <= dma_write_length_counter[31:0];
                            end
                            DEBUG_READ_CMD: begin
                                 axil_rdata <= dma_read_cmd_counter;
                            end
                            DEBUG_READ_WORD: begin
                                 axil_rdata <= dma_read_word_counter;
                            end
                            DEBUG_READ_PKG: begin
                                 axil_rdata <= dma_read_pkg_counter;
                            end
                            DEBUG_READ_LEN: begin
                                axil_rdata <= dma_read_length_counter[31:0];
                            end
                            DEBUG_TLB_MISS: begin
                                axil_rdata <= tlb_miss_counter;
                            end
                            DEBUG_TLB_PAGE_CROSS: begin
                                axil_rdata <= tlb_boundary_crossing_counter;
                            end
                            default: begin
                                axil_rresp <= AXI_RESP_SLVERR;
                                axil_rdata <= 0;
                            end
                        endcase
                    end
                    default: begin
                        axil_rresp <= AXI_RESP_SLVERR;
                        axil_rdata <= 32'hdeadbeef;
                    end
                endcase
                if (axil_rvalid && axil_rready) begin
                    axil_rvalid <= 1'b0;
                    /*if (readAddr == GPIO_REG_DEBUG) begin
                        read_addr <= read_addr + 1;
                    end*/
                    if (readAddr == GPIO_REG_DEBUG2) begin
                        debugRegAddr <= debugRegAddr + 1;
                    end
                    if (readAddr == GPIO_REG_DMA_READS) begin
                        dma_read_length_upper <= ~dma_read_length_upper;
                    end
                    if (readAddr == GPIO_REG_DMA_WRITES) begin
                        dma_write_length_upper <= ~dma_write_length_upper;
                    end
                    readState <= READ_IDLE;
                end
            end
        endcase
    end
end

endmodule
`default_nettype wire
