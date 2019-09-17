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


module adm7v3_10g_interface(
    // 200MHz reference clock input
    input wire              reset,
    input wire              aresetn,
    
    // 156.25 MHz clock in
    input wire              xphy_refclk_p,
    input wire              xphy_refclk_n,
    
    output logic            xphy0_txp,
    output logic            xphy0_txn,
    input wire              xphy0_rxp,
    input wire              xphy0_rxn,
  
    output logic            xphy1_txp,
    output logic            xphy1_txn,
    input wire              xphy1_rxp,
    input wire              xphy1_rxn,
    
    /*output                         xphy2_txp,
    output                         xphy2_txn,
    input                          xphy2_rxp,
    input                          xphy2_rxn,    
    output                         xphy3_txp,
    output                         xphy3_txn,
    input                          xphy3_rxp,
    input                          xphy3_rxn,*/

    axi_stream.master   m_axis_net_rx[NUM_NET_PORTS],
    axi_stream.slave    s_axis_net_tx[NUM_NET_PORTS],

    output logic[3:0]   sfp_tx_disable,
    output logic        clk156_out,
    output logic        clk_ref_200_out,
    output logic        network_reset_done,
    
    output logic[7:0]   led 

);



wire                                  clk_ref_200;

wire[7:0] core0_status;
wire[7:0] core1_status;
wire[7:0] core2_status;
wire[7:0] core3_status;

// Shared clk signals
wire gt_txclk322;
wire gt_txusrclk;
wire gt_txusrclk2;
wire gt_qplllock;
wire gt_qplloutclk;
wire gt_qpllrefclklost;
wire gt_qplloutrefclk;
wire gt_qplllock_txusrclk2;
wire gttxreset_txusrclk2;
wire gt_txuserrdy;
wire tx_fault;
wire core_reset;
wire gt0_tx_resetdone;
wire gt1_tx_resetdone;
wire gt2_tx_resetdone;
wire gt3_tx_resetdone;
wire areset_clk_156_25_bufh;
wire areset_clk_156_25;
wire mmcm_locked_clk156;
wire reset_counter_done;
wire gttxreset;
wire gtrxreset;
wire clk156_25;
wire dclk_i;
wire xphyrefclk_i;

assign network_reset_done = ~core_reset;

assign clk156_out = clk156_25;
assign clk_ref_200_out = clk_ref_200;
/*
 * Clocks
 */


/*
 * Network modules
 */

wire[7:0]   tx_ifg_delay;
wire        signal_detect;
//wire        tx_fault;
assign tx_ifg_delay     = 8'h00; 
assign signal_detect    = 1'b1;
//assign tx_fault         = 1'b0;


network_module network_inst_0
(
.clk156 (clk156_25),
.reset(reset),
.aresetn(aresetn),
.dclk                             (dclk_i),
.txusrclk                         (gt_txusrclk),
.txusrclk2                        (gt_txusrclk2),
.txclk322                         (gt_txclk322),

.areset_refclk_bufh               (areset_clk_156_25_bufh),
.areset_clk156                    (areset_clk_156_25),
.mmcm_locked_clk156              (mmcm_locked_clk156),
.gttxreset_txusrclk2              (gttxreset_txusrclk2),
.gttxreset                        (gttxreset),
.gtrxreset                        (gtrxreset),
.txuserrdy                        (gt_txuserrdy),
.qplllock                         (gt_qplllock),
.qplloutclk                       (gt_qplloutclk),
.qplloutrefclk                    (gt_qplloutrefclk),
.reset_counter_done               (reset_counter_done),
.tx_resetdone                      (gt0_tx_resetdone),

.txp(xphy0_txp),
.txn(xphy0_txn),
.rxp(xphy0_rxp),
.rxn(xphy0_rxn),
//TODO
.tx_axis_tdata(s_axis_net_tx[0].data),
.tx_axis_tvalid(s_axis_net_tx[0].valid),
.tx_axis_tlast(s_axis_net_tx[0].last),
.tx_axis_tuser(1'b0),
.tx_axis_tkeep(s_axis_net_tx[0].keep),
.tx_axis_tready(s_axis_net_tx[0].ready),

.rx_axis_tdata(m_axis_net_rx[0].data),
.rx_axis_tvalid(m_axis_net_rx[0].valid),
.rx_axis_tuser(),
.rx_axis_tlast(m_axis_net_rx[0].last),
.rx_axis_tkeep(m_axis_net_rx[0].keep),
.rx_axis_tready(m_axis_net_rx[0].ready),

.core_reset(core_reset),
.tx_fault(tx_fault),
.signal_detect(signal_detect),
.tx_ifg_delay(tx_ifg_delay),
.tx_disable(),
.rx_fifo_overflow(),
.rx_statistics_vector(),
.rx_statistics_valid(),
.core_status(core0_status)
);


network_module network_inst_1
(
.clk156 (clk156_25),
.reset(reset),
.aresetn(aresetn),
.dclk                             (dclk_i),
.txusrclk                         (gt_txusrclk),
.txusrclk2                        (gt_txusrclk2),
.txclk322                         (),

.areset_refclk_bufh               (areset_clk_156_25_bufh),
.areset_clk156                    (areset_clk_156_25),
.mmcm_locked_clk156              (mmcm_locked_clk156),
.gttxreset_txusrclk2              (gttxreset_txusrclk2),
.gttxreset                        (gttxreset),
.gtrxreset                        (gtrxreset),
.txuserrdy                        (gt_txuserrdy),
.qplllock                         (gt_qplllock),
.qplloutclk                       (gt_qplloutclk),
.qplloutrefclk                    (gt_qplloutrefclk),
.reset_counter_done               (reset_counter_done),
.tx_resetdone                      (gt1_tx_resetdone),

.txp(xphy1_txp),
.txn(xphy1_txn),
.rxp(xphy1_rxp),
.rxn(xphy1_rxn),

//TODO
.tx_axis_tdata(s_axis_net_tx[1].data),
.tx_axis_tvalid(s_axis_net_tx[1].valid),
.tx_axis_tlast(s_axis_net_tx[1].last),
.tx_axis_tuser(1'b0),
.tx_axis_tkeep(s_axis_net_tx[1].keep),
.tx_axis_tready(s_axis_net_tx[1].ready),

.rx_axis_tdata(m_axis_net_rx[1].data),
.rx_axis_tvalid(m_axis_net_rx[1].valid),
.rx_axis_tuser(),
.rx_axis_tlast(m_axis_net_rx[1].last),
.rx_axis_tkeep(m_axis_net_rx[1].keep),
.rx_axis_tready(m_axis_net_rx[1].ready),

.core_reset(core_reset),
.tx_fault(tx_fault),
.signal_detect(signal_detect),
.tx_ifg_delay(tx_ifg_delay),
.tx_disable(),
.rx_fifo_overflow(),
.rx_statistics_vector(),
.rx_statistics_valid(),
.core_status(core1_status)
);

//wire xphyrefclk_i;

IBUFDS_GTE2 xgphy_refclk_ibuf (

    .I      (xphy_refclk_p),
    .IB     (xphy_refclk_n),
    .O      (xphyrefclk_i  ),
    .CEB    (1'b0          ),
    .ODIV2  (              )   

);


//assign gt1_tx_resetdone = 1'b1;
assign gt2_tx_resetdone = 1'b1;
assign gt3_tx_resetdone = 1'b1;

xgbaser_gt_same_quad_wrapper #(
.WRAPPER_SIM_GTRESET_SPEEDUP     ("TRUE"                        )
) xgbaser_gt_wrapper_inst (
.gt_txclk322                       (gt_txclk322),
.gt_txusrclk                       (gt_txusrclk),
.gt_txusrclk2                      (gt_txusrclk2),
.qplllock                          (gt_qplllock),
.qpllrefclklost                    (gt_qpllrefclklost),
.qplloutclk                        (gt_qplloutclk),
.qplloutrefclk                     (gt_qplloutrefclk),
.qplllock_txusrclk2                (gt_qplllock_txusrclk2), //not used
.gttxreset_txusrclk2               (gttxreset_txusrclk2),
.txuserrdy                         (gt_txuserrdy),
.tx_fault                          (tx_fault), 
.core_reset                        (core_reset),
.gt0_tx_resetdone                  (gt0_tx_resetdone),
.gt1_tx_resetdone                  (gt1_tx_resetdone),
.gt2_tx_resetdone                  (gt2_tx_resetdone),
.gt3_tx_resetdone                  (gt3_tx_resetdone),
.areset_clk_156_25_bufh            (areset_clk_156_25_bufh),
.areset_clk_156_25                 (areset_clk_156_25),
.mmcm_locked_clk156                (mmcm_locked_clk156),
.reset_counter_done                (reset_counter_done),
.gttxreset                         (gttxreset),
.gtrxreset                         (gtrxreset),
.clk156                            (clk156_25            ),
.areset                            (reset),  
.dclk                              (dclk_i                     ), 
.gt_refclk                         (xphyrefclk_i               )
);
    
assign sfp_tx_disable = 4'b0000;

localparam  LED_CTR_WIDTH           = 26;
reg     [LED_CTR_WIDTH-1:0]           l1_ctr;
reg     [LED_CTR_WIDTH-1:0]           l2_ctr;

always @(posedge clk156_25)
begin
    l1_ctr <= l1_ctr + {{(LED_CTR_WIDTH-1){1'b0}}, 1'b1};
end

assign led[0] = l1_ctr[LED_CTR_WIDTH-1];
assign led[1] = l2_ctr[LED_CTR_WIDTH-1];
//assign led[2] = reset;
//assign led[3] = core_reset;
assign led[2] = core0_status[0];

endmodule
`default_nettype wire
