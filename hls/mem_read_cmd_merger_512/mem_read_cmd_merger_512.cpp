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
#include "mem_read_cmd_merger_512.hpp"


template <int DUMMY>
void calculate_page_offset(	hls::stream<memCmd>&			cmdIn,
							hls::stream<internalCmd>&		cmdOut,
							ap_uint<48>						regBaseVaddr)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE=off

	if (!cmdIn.empty())
	{
		memCmd cmd = cmdIn.read();
		ap_uint<48> addr = cmd.addr - regBaseVaddr;
		ap_uint<24> page_offset = (addr & 0x1FFFFF);
		ap_uint<24> newLength = PAGE_SIZE-page_offset;
		cmdOut.write(internalCmd(cmd.addr, cmd.len, page_offset, newLength));
	}
}

template <int ROUTE>
void split_command(hls::stream<internalCmd>&	cmdIn,
						hls::stream<memCmd>&			cmdOut,
						hls::stream<routeInfo>&		routeInfoFifo)
{
	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off

	enum splitStateType {CMD, SPLIT};
	static splitStateType state = CMD;
	static internalCmd cmd;

	switch (state)
	{
	case CMD:
		if (!cmdIn.empty())
		{
			cmdIn.read(cmd);

			if (cmd.page_offset + cmd.len > PAGE_SIZE)
			{
				cmdOut.write(memCmd(cmd.addr, cmd.new_length));
				cmd.addr += cmd.new_length;
				cmd.len -= cmd.new_length;
				state = SPLIT;
				routeInfoFifo.write(routeInfo(ROUTE));
			}
			else
			{
				cmdOut.write(memCmd(cmd.addr, cmd.len));
				routeInfoFifo.write(routeInfo(ROUTE, true));
			}
		}
		break;
	case SPLIT:
		if (cmd.len > PAGE_SIZE)
		{
			cmdOut.write(memCmd(cmd.addr, PAGE_SIZE));
			cmd.addr += PAGE_SIZE;
			cmd.len -= PAGE_SIZE;
			routeInfoFifo.write(routeInfo(ROUTE));
		}
		else
		{
			cmdOut.write(memCmd(cmd.addr, cmd.len));
			routeInfoFifo.write(routeInfo(ROUTE, true));
			state = CMD;
		}

		break;
	}//switch
}

void merger(hls::stream<memCmd>&			cmdIn0,
				hls::stream<routeInfo>&		routeInfoIn0,
				hls::stream<memCmd>&			cmdIn1,
				hls::stream<routeInfo>&		routeInfoIn1,
				hls::stream<memCmd>&			cmdOut,
				hls::stream<ap_uint<1> >&	routeInfoFifo,
				hls::stream<stitchInfo>&	stitchInfoFifo)
{
	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off

	enum mergStateType{IDLE, FWD0, FWD1};
	static mergStateType state = IDLE;

	switch (state)
	{
	case IDLE:
		if (!cmdIn0.empty() && !routeInfoIn0.empty())
		{
			memCmd cmd = cmdIn0.read();
			routeInfo info = routeInfoIn0.read();
			cmdOut.write(memCmd(cmd));
			routeInfoFifo.write(info.route);
			stitchInfoFifo.write(stitchInfo(cmd.len(5, 0), info.last));

			if (!info.last)
			{
				state = FWD0;
			}
		}
		else if (!cmdIn1.empty() && !routeInfoIn1.empty())
		{
			memCmd cmd = cmdIn1.read();
			routeInfo info = routeInfoIn1.read();
			cmdOut.write(memCmd(cmd));
			routeInfoFifo.write(info.route);
			stitchInfoFifo.write(stitchInfo(cmd.len(5, 0), info.last));

			if (!info.last)
			{
				state = FWD1;
			}
		}
		break;
	case FWD0:
		if (!cmdIn0.empty() && !routeInfoIn0.empty())
		{
			memCmd cmd = cmdIn0.read();
			routeInfo info = routeInfoIn0.read();
			cmdOut.write(memCmd(cmd));
			stitchInfoFifo.write(stitchInfo(info.last));

			if (info.last)
			{
				state = IDLE;
			}
		}
		break;
	case FWD1:
		if (!cmdIn1.empty() && !routeInfoIn1.empty())
		{
			memCmd cmd = cmdIn1.read();
			routeInfo info = routeInfoIn1.read();
			cmdOut.write(memCmd(cmd));
			//routeInfoFifo.write(route);
			stitchInfoFifo.write(stitchInfo(info.last));

			if (info.last)
			{
				state = IDLE;
			}
		}
		break;
	}//switch
}

void data_stitching(	hls::stream<stitchInfo>&		stitchInfoFifo,
							hls::stream<net_axis<512> >&	dataIn,
							hls::stream<net_axis<512> >&	dataOut)
{
	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off


	enum fsmStateType {IDLE, FIRST_PART, STITCH_FIRST, STITCH, RESIDUE};
	static fsmStateType state = IDLE;
	static ap_uint<6> offset = 0;
	static net_axis<512> prevWord;
	static bool isLast = true;

	switch (state)
	{
	case IDLE:
		if (!stitchInfoFifo.empty() && !dataIn.empty())
		{
			stitchInfo info =  stitchInfoFifo.read();
			offset = info.offset;
			isLast = info.isLast;
			net_axis<512> currWord = dataIn.read();

			//Check if packet has only 1 word
			if (currWord.last)
			{
				if (!isLast)
				{
					currWord.last = 0;
					if (currWord.keep[63] == 0)
					{
						//currWord is stored in prevWord
						state = STITCH_FIRST;
					}
					else
					{
						//We remain in this state since we have to read lastPartFifo for the next part
						dataOut.write(currWord);
					}
					
				}
				else //packet does not have to merged
				{
					//We remain in this state
					dataOut.write(currWord);
				}
				
			}
			else //packet contains more than one word
			{
				dataOut.write(currWord);
				state = FIRST_PART;
			}
			prevWord = currWord;
		}
		break;
	case FIRST_PART:
		if (!dataIn.empty())
		{
			net_axis<512> currWord = dataIn.read();

			//Check if packet has only 1 word
			if (currWord.last)
			{
				if (!isLast)
				{
					currWord.last = 0;
					if (currWord.keep[63] == 0)
					{
						//currWord is stored in prevWord
						state = STITCH_FIRST;
					}
					else
					{
						dataOut.write(currWord);
						state = IDLE;
					}
					
				}
				else //packet does not have to be merged
				{
					dataOut.write(currWord);
					state = IDLE;
				}
				
			}
			else
			{
				//We remain in this state until last
				dataOut.write(currWord);
			}
			prevWord = currWord;
		}
		break;
	case STITCH_FIRST:
		if (!stitchInfoFifo.empty() && !dataIn.empty())
		{
			stitchInfo info = stitchInfoFifo.read();
			isLast = info.isLast;
			net_axis<512> sendWord;
			sendWord.last = 0;
			net_axis<512> currWord = dataIn.read();

			//Create new word consisting of current and previous word
			// offset specifies how many bytes of prevWord are valid
			sendWord.data((offset*8) -1, 0) = prevWord.data((offset*8) -1, 0);
			sendWord.keep(offset-1, 0) = prevWord.keep(offset -1, 0);

			sendWord.data(512-1, (offset*8)) = currWord.data(512 - (offset*8) - 1, 0);
			sendWord.keep(512/8-1, offset) = currWord.keep(512/8 - offset - 1, 0);
			sendWord.last = (isLast) && (currWord.keep[512/8 - offset] == 0);

			dataOut.write(sendWord);
			prevWord.data((offset*8) - 1, 0) = currWord.data(512-1, 512 - (offset*8));
			prevWord.keep(offset - 1, 0) = currWord.keep(512/8 - 1, 512/8 - offset);
			if (currWord.last)
			{
				if (isLast)
				{
					state = IDLE;
					if (!sendWord.last)
					{
						state = RESIDUE;
					}
				}
			}
			else
			{
				state = STITCH;
			}
			
		}
		break;
	case STITCH:
		if (!dataIn.empty())
		{
			net_axis<512> sendWord;
			sendWord.last = 0;
			net_axis<512> currWord = dataIn.read();

			//Create new word consisting of current and previous word
			// offset specifies how many bytes of prevWord are valid
			sendWord.data((offset*8) -1, 0) = prevWord.data((offset*8) -1, 0);
			sendWord.keep(offset-1, 0) = prevWord.keep(offset -1, 0);

			sendWord.data(512-1, (offset*8)) = currWord.data(512 - (offset*8) - 1, 0);
			sendWord.keep(512/8-1, offset) = currWord.keep(512/8 - offset - 1, 0);
			sendWord.last = (isLast) && (currWord.keep[512/8 - offset] == 0);

			dataOut.write(sendWord);
			prevWord.data((offset*8) - 1, 0) = currWord.data(512-1, 512 - (offset*8));
			prevWord.keep(offset - 1, 0) = currWord.keep(512/8 - 1, 512/8 - offset);
			if (currWord.last)
			{
				if (isLast)
				{
					state = IDLE;
					if (!sendWord.last)
					{
						state = RESIDUE;
					}
				}
				else
				{
					state = STITCH_FIRST;
				}
				
			}
		}
		break;
	case RESIDUE:
		{
			net_axis<512> sendWord;
			sendWord.data((offset*8) -1, 0) = prevWord.data((offset*8) -1, 0);
			sendWord.keep(offset-1, 0) = prevWord.keep(offset -1, 0);
#ifndef __SYNTHESIS__
			sendWord.data(512-1, (offset*8)) = 0;
#endif
			sendWord.keep(512/8-1, offset) = 0;
			sendWord.last = 1;

			dataOut.write(sendWord);
			state = IDLE;
		}
		break;
	}//switch
}

void arbiter(	hls::stream<ap_uint<1> >&		routeFifo,
				hls::stream<net_axis<512> >& dataIn,
				hls::stream<net_axis<512> >&	dataOut0,
				hls::stream<net_axis<512> >& dataOut1)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	enum stateType{IDLE, FWD0, FWD1};
	static stateType state = IDLE;
	net_axis<512> currWord;

	switch (state)
	{
	case IDLE:
		if (!routeFifo.empty())
		{
			ap_uint<1> route = routeFifo.read();
			std::cout << "ROUTE: " << route << std::endl;
			state = (route == 0) ? FWD0 : FWD1;
		}
		break;
	case FWD0:
		if (!dataIn.empty())
		{
			dataIn.read(currWord);
			dataOut0.write(currWord);
			if (currWord.last)
			{
				state = IDLE;
			}
		}
		break;
	case FWD1:
		if (!dataIn.empty())
		{
			dataIn.read(currWord);
			dataOut1.write(currWord);
			if (currWord.last)
			{
				state = IDLE;
			}
		}
		break;
	}//switch
}

void mem_read_cmd_merger_512(	hls::stream<memCmd>&			cmdIn0,
								hls::stream<memCmd>&			cmdIn1,
								hls::stream<memCmd>&			cmdOut,
								hls::stream<net_axis<512> >& dataIn,
								hls::stream<net_axis<512> >& dataOut0,
								hls::stream<net_axis<512> >& dataOut1,
								ap_uint<64>				regbaseVaddr)
{
#pragma HLS DATAFLOW disable_start_propagation
#pragma HLS INTERFACE ap_ctrl_none port=return

	#pragma HLS INTERFACE axis register port=cmdIn0 name=s_axis_cmd0
	#pragma HLS INTERFACE axis register port=cmdIn1 name=s_axis_cmd1
	#pragma HLS INTERFACE axis register port=cmdOut name=m_axis_cmd
	#pragma HLS INTERFACE axis register port=dataIn name=s_axis_data
	#pragma HLS INTERFACE axis register port=dataOut0 name=m_axis_data0
	#pragma HLS INTERFACE axis register port=dataOut1 name=m_axis_data1
	#pragma HLS DATA_PACK variable=cmdIn0
	#pragma HLS DATA_PACK variable=cmdIn1
	#pragma HLS DATA_PACK variable=cmdOut
	#pragma HLS INTERFACE ap_none port=regbaseVaddr


	static hls::stream<internalCmd>	pageOffsetFifo0("pageOffsetFifo0");
	static hls::stream<internalCmd>	pageOffsetFifo1("pageOffsetFifo1");
	static hls::stream<memCmd>			cmdFifo0("cmdFifo0");
	static hls::stream<memCmd>			cmdFifo1("cmdFifo1");
	static hls::stream<routeInfo> 	routeInfoFifo0("routeInfoFifo0");
	static hls::stream<routeInfo> 	routeInfoFifo1("routeInfoFifo1");
	static hls::stream<ap_uint<1> > 	routeFifo("routeFifo");
	static hls::stream<stitchInfo>	stitchInfoFifo("stitchInfoFifo");
	static hls::stream<net_axis<512> >	stitchedDataFifo("stitchedDataFifo");
	#pragma HLS stream variable=pageOffsetFifo0 depth=2
	#pragma HLS stream variable=pageOffsetFifo1 depth=2
	#pragma HLS stream variable=cmdFifo0 depth=2
	#pragma HLS stream variable=cmdFifo1 depth=2
	#pragma HLS stream variable=routeInfoFifo0 depth=2
	#pragma HLS stream variable=routeInfoFifo1 depth=2
	#pragma HLS stream variable=routeFifo depth=32
	#pragma HLS stream variable=stitchInfoFifo depth=32
	#pragma HLS stream variable=stitchedDataFifo depth=2
	#pragma HLS DATA_PACK variable=pageOffsetFifo0
	#pragma HLS DATA_PACK variable=pageOffsetFifo0
	#pragma HLS DATA_PACK variable=cmdFifo0
	#pragma HLS DATA_PACK variable=cmdFifo1
	#pragma HLS DATA_PACK variable=routeInfoFifo0
	#pragma HLS DATA_PACK variable=routeInfoFifo1
	#pragma HLS DATA_PACK variable=stitchInfoFifo
	#pragma HLS DATA_PACK variable=stitchedDataFifo


	calculate_page_offset<0>(cmdIn0, pageOffsetFifo0, regbaseVaddr);
	calculate_page_offset<1>(cmdIn1, pageOffsetFifo1, regbaseVaddr);

	split_command<0>(pageOffsetFifo0, cmdFifo0, routeInfoFifo0);
	split_command<1>(pageOffsetFifo1, cmdFifo1, routeInfoFifo1);

	merger(cmdFifo0, routeInfoFifo0, cmdFifo1, routeInfoFifo1, cmdOut, routeFifo, stitchInfoFifo);

	data_stitching(stitchInfoFifo, dataIn, stitchedDataFifo);

	arbiter(routeFifo, stitchedDataFifo, dataOut0, dataOut1);
}
