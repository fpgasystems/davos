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

module ddr_controller
(
    //clk
    input  wire         pcie_clk,
    input  wire         pcie_aresetn,
    // user clk
    input wire          mem_clk,
    input wire          mem_aresetn,

    //Control interface
    axi_lite.slave      s_axil,
    
    input wire[31:0]    write_cmd_counter,
    input wire[31:0]    write_word_counter,
    input wire[31:0]    write_pkg_counter,
    input wire[47:0]    write_length_counter,
    input wire[31:0]    write_sts_counter,
    input wire[31:0]    write_sts_error_counter,

    input wire[31:0]    read_cmd_counter,
    input wire[31:0]    read_word_counter,
    input wire[31:0]    read_pkg_counter,
    input wire[47:0]    read_length_counter,
    input wire[31:0]    read_sts_counter,
    input wire[31:0]    read_sts_error_counter,

    input wire          s2mm_error,
    input wire          mm2s_error

);

localparam AXI_RESP_OK = 2'b00;
localparam AXI_RESP_SLVERR = 2'b10;

//WRITE states
localparam WRITE_IDLE = 0;
localparam WRITE_DATA = 1;
localparam WRITE_RESPONSE = 2;

//READ states
localparam READ_IDLE = 0;
localparam READ_RESPONSE = 1;

//ADDRESES
localparam GPIO_REG_DEBUG       = 8'h00;
localparam GPIO_REG_STATS       = 8'h01;
localparam GPIO_REG_DDR_READS   = 8'h03;
localparam GPIO_REG_DDR_WRITES  = 8'h04;

//Status Registers
localparam NUM_STATS_REGS = 13;
//TODO use enum
localparam STATS_WRITE_CMD  = 8'h00;
localparam STATS_WRITE_WORD = 8'h01;
localparam STATS_WRITE_PKG  = 8'h02;
localparam STATS_WRITE_LEN  = 8'h03;
localparam STATS_WRITE_STS  = 8'h04;
localparam STATS_WRITE_ERRORS   = 8'h05;

localparam STATS_READ_CMD   = 8'h06;
localparam STATS_READ_WORD  = 8'h07;
localparam STATS_READ_PKG   = 8'h08;
localparam STATS_READ_LEN   = 8'h09;
localparam STATS_READ_STS   = 8'h0A;
localparam STATS_READ_ERRORS    = 8'h0B;

localparam STATS_DM_ERRORS  = 8'h0C;

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

  .m_axi_aclk(mem_clk),        // input wire m_axi_aclk
  .m_axi_aresetn(mem_aresetn),  // input wire m_axi_aresetn
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

reg[7:0] readAddr;

//handle writes => always return default ERROR
always @(posedge mem_clk)
begin
    if (~mem_aresetn) begin
        axil_awready <= 1'b0;
        axil_wready <= 1'b0;
        axil_bvalid <= 1'b0;
        
        writeState <= WRITE_IDLE;
    end
    else begin
        case (writeState)
            WRITE_IDLE: begin
                axil_awready <= 1'b1;
                axil_wready <= 1'b0;
                axil_bvalid <= 1'b0;
                
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
                    axil_bresp <= AXI_RESP_SLVERR;
                    writeState <= WRITE_RESPONSE;
                end
            end //WRITE_DATA
            WRITE_RESPONSE: begin
                axil_bvalid <= 1'b1;
                if (axil_bvalid && axil_bready) begin
                    axil_bvalid <= 1'b0;
                    writeState <= WRITE_IDLE;
                end
            end//WRITE_RESPONSE
        endcase
    end
end

//handle reads
reg[7:0] statsRegAddr;
reg read_length_upper;
reg write_length_upper;
always @(posedge mem_clk)
begin
    if (~mem_aresetn) begin
        axil_arready <= 1'b0;
        axil_rresp <= 0;
        axil_rvalid <= 1'b0;
        //read_en <= 0;
        readState <= READ_IDLE;
        //read_addr <= 0;
        statsRegAddr <= 0;
        read_length_upper <= 0;
        write_length_upper <= 0;
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
                if (statsRegAddr == NUM_STATS_REGS) begin
                    statsRegAddr <= 0;
                end
            end
            READ_RESPONSE: begin
                axil_rvalid <= 1'b1;
                axil_rresp <= AXI_RESP_OK;
                case (readAddr)
                    /*GPIO_REG_DEBUG: begin
                        axil_rdata <= read_data;
                    end*/
                    GPIO_REG_STATS: begin
                        case (statsRegAddr)
                            STATS_WRITE_CMD: begin
                                 axil_rdata <= write_cmd_counter;
                            end
                            STATS_WRITE_WORD: begin
                                 axil_rdata <= write_word_counter;
                            end
                            STATS_WRITE_PKG: begin
                                 axil_rdata <= write_pkg_counter;
                            end
                            STATS_WRITE_LEN: begin
                                axil_rdata <= write_length_counter[31:0];
                            end
                            STATS_WRITE_STS: begin
                                axil_rdata <= write_sts_counter;
                            end
                            STATS_WRITE_ERRORS: begin
                                axil_rdata <= write_sts_error_counter;
                            end
                            STATS_READ_CMD: begin
                                 axil_rdata <= read_cmd_counter;
                            end
                            STATS_READ_WORD: begin
                                 axil_rdata <= read_word_counter;
                            end
                            STATS_READ_PKG: begin
                                 axil_rdata <= read_pkg_counter;
                            end
                            STATS_READ_LEN: begin
                                axil_rdata <= read_length_counter[31:0];
                            end
                            STATS_READ_STS: begin
                                axil_rdata <= read_sts_counter;
                            end
                            STATS_READ_ERRORS: begin
                                axil_rdata <= read_sts_error_counter;
                            end
                            STATS_DM_ERRORS: begin
                                axil_rdata[0] <= s2mm_error;
                                axil_rdata[1] <= mm2s_error;
                                axil_rdata[31:2] <= '0;
                            end
                            default: begin
                                axil_rresp <= AXI_RESP_SLVERR;
                                axil_rdata <= 0;
                            end
                        endcase
                    end
                    GPIO_REG_DDR_READS: begin
                        if (!read_length_upper) begin
                            axil_rdata <= read_length_counter[31:0];
                        end
                        else begin
                            axil_rdata[15:0] <= read_length_counter[47:32];
                            axil_rdata[31:16] <= 0;
                        end
                    end
                    GPIO_REG_DDR_WRITES: begin
                        if (!write_length_upper) begin
                            axil_rdata <= write_length_counter[31:0];
                        end
                        else begin
                            axil_rdata[15:0] <= write_length_counter[47:32];
                            axil_rdata[31:16] <= 0;
                        end
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
                    if (readAddr == GPIO_REG_STATS) begin
                        statsRegAddr <= statsRegAddr + 1;
                    end
                    if (readAddr == GPIO_REG_DDR_READS) begin
                        read_length_upper <= ~read_length_upper;
                    end
                    if (readAddr == GPIO_REG_DDR_WRITES) begin
                        write_length_upper <= ~write_length_upper;
                    end

                    readState <= READ_IDLE;
                end
            end
        endcase
    end
end

endmodule
`default_nettype wire
