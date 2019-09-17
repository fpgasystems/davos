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
`ifndef DAVOS_TYPES_SVH_
`define DAVOS_TYPES_SVH_
`default_nettype none

/*typedef struct packed {
    logic[511:0]    data;
    logic[63:0]     keep;
    logic           last;
} axi_word_512_t;

typedef struct packed {
    logic[63:0]     address;
    logic[31:0]     length;
} mem_cmd_t;*/


interface axis_mem_cmd;
    logic valid;
    logic ready;
    logic[63:0]     address;
    logic[31:0]     length;
    //logic           dest;

    modport master (output valid,
                    input ready,
                    output address,
                    output length);

    modport slave ( input valid,
                    output ready,
                    input address,
                    input length);

    /*modport rmaster(output valid,
                    input ready,
                    output address,
                    output length,
                    output dest);*/

endinterface

interface axi_stream #(
    parameter WIDTH = 512
);
    logic valid;
    logic ready;
    logic[WIDTH-1:0]    data;
    logic[(WIDTH/8)-1:0] keep;
    logic           last;
    logic           dest;

    modport master (output valid,
                    input ready,
                    output data,
                    output keep,
                    output last);

    modport slave ( input valid,
                    output ready,
                    input data,
                    input keep,
                    input last);

    modport rmaster(output valid,
                    input ready,
                    output data,
                    output keep,
                    output last,
                    output dest);

    /*modport rslave (input valid,
                    output ready,
                    input data,
                    input keep,
                    input last,
                    input dest);*/

endinterface

interface axis_mem_status;
    logic valid;
    logic ready;
    logic[7:0]     data;

    modport master (output valid,
                    input  ready,
                    output data);

    modport slave ( input  valid,
                    output ready,
                    input  data);
endinterface

interface axis_meta #(
    parameter WIDTH = 96,
    parameter DEST_WIDTH = 1
);
    logic valid;
    logic ready;
    logic[WIDTH-1:0]        data;
    logic[DEST_WIDTH-1:0]   dest;

    modport master (output valid,
                    input ready,
                    output data);

    modport slave ( input valid,
                    output ready,
                    input data);

    modport rmaster(output valid,
                    input ready,
                    output data,
                    output dest);

endinterface


interface axi_lite;
    //write address
    logic [31: 0]   awaddr;
    logic           awvalid;
    logic           awready;
 
    //write data
    logic [31: 0]   wdata;
    logic [3: 0]    wstrb;
    logic           wvalid;
    logic           wready;
 
    //write response (handhake)
    logic [1:0]     bresp;
    logic           bvalid;
    logic           bready;
 
    //read address
    logic [31: 0]   araddr;
    logic           arvalid;
    logic           arready;
 
    //read data
    logic [31: 0]   rdata;
    logic [1:0]     rresp;
    logic           rvalid;
    logic           rready;

    modport master (output  awvalid,
                    input   awready,
                    output  awaddr,
                    output  wdata,
                    output  wstrb,
                    output  wvalid,
                    input   wready,
                    input   bvalid,
                    output  bready,
                    input   bresp,
                    output  arvalid,
                    input   arready,
                    output  araddr,
                    input   rvalid,
                    output  rready,
                    input   rdata,
                    input   rresp);

    modport slave ( input   awvalid,
                    output  awready,
                    input   awaddr,
                    input   wdata,
                    input   wstrb,
                    input   wvalid,
                    output  wready,
                    output  bvalid,
                    input   bready,
                    output  bresp,
                    input   arvalid,
                    output  arready,
                    input   araddr,
                    output  rvalid,
                    input   rready,
                    output  rdata,
                    output  rresp);

endinterface

interface axi_mm;
    //write address
    logic [3:0]     awid;
    logic [7:0]     awlen;
    logic [2:0]     awsize;
    logic [1:0]     awburst;    
    logic [3:0]     awcache;
    logic [2:0]     awprot;
    logic [63:0]    awaddr;
    logic           awlock;
    logic           awvalid;
    logic           awready;
 
    //write data
    logic [255:0]   wdata;
    logic [31:0]    wstrb;
    logic           wlast;
    logic           wvalid;
    logic           wready;

    //write response (handhake)
    logic [3:0]     bid;
    logic [1:0]     bresp;
    logic           bvalid;
    logic           bready;
 
    //read address
    logic [3:0]     arid;
    logic [63: 0]   araddr;
    logic [7:0]     arlen;
    logic [2:0]     arsize;
    logic [1:0]     arburst;
    logic [3:0]     arcache;
    logic [2:0]     arprot;
    logic           arlock;
    logic           arvalid;
    logic           arready;
 
    //read data
    logic [3:0]     rid;
    logic [1:0]     rresp; 
    logic [255:0]   rdata;
    logic           rvalid;
    logic           rlast;
    logic           rready;

    modport master (output  awid,
                    output  awlen, 
                    output  awsize,
                    output  awburst,
                    output  awcache,
                    output  awprot,
                    output  awaddr,
                    output  awlock,
                    output  awvalid,
                    input   awready,
                                
                    output  wdata,
                    output  wstrb,
                    output  wlast,
                    output  wvalid,
                    input   wready,                    

                    input   bid,
                    input   bresp,
                    input   bvalid,
                    output  bready,

                    output  arid,
                    output  araddr,
                    output  arlen,
                    output  arsize,
                    output  arburst,
                    output  arcache,
                    output  arprot,
                    output  arlock,
                    output  arvalid,
                    input   arready,

                    input   rid,
                    input   rresp,
                    input   rdata,                  
                    input   rvalid,
                    input   rlast,
                    output  rready);


     modport slave (input   awid,
                    input   awlen, 
                    input   awsize,
                    input   awburst,
                    input   awcache,
                    input   awprot,
                    input   awaddr,
                    input   awlock,
                    input   awvalid,
                    output  awready,
                                  
                    input   wdata,
                    input   wstrb,
                    input   wlast,
                    input   wvalid,
                    output  wready,                    

                    output  bid,
                    output  bresp,
                    output  bvalid,
                    input   bready,

                    input   arid,
                    input   araddr,
                    input   arlen,
                    input   arsize,
                    input   arburst,
                    input   arcache,
                    input   arprot,
                    input   arlock,
                    input   arvalid,
                    output  arready,

                    output  rid,
                    output  rresp,
                    output  rdata,                   
                    output  rvalid,
                    output  rlast,
                    input   rready);
endinterface



`endif
