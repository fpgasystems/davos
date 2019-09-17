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
#include "mem_write_cmd_page_boundary_check_512.hpp"

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

void boundary_check(hls::stream<internalCmd>&		cmdIn,
					hls::stream<memCmd>&			cmdOut,
					hls::stream<boundCheckMeta>&	metaOut)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE=off

	enum bcStateType{CMD, CMD_SPLIT};
	static bcStateType bc_state = CMD;
	static internalCmd cmd;

	switch (bc_state)
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
				metaOut.write(boundCheckMeta(cmd.new_length, true));
				bc_state = CMD_SPLIT;
			}
			else
			{
				cmdOut.write(memCmd(cmd.addr, cmd.len));
				metaOut.write(boundCheckMeta(cmd.len, false));
			}
		}
		break;
	case CMD_SPLIT:
		//TODO handle multiple splits
		/*if (cmd.len > PAGE_SIZE)
		{
			cmdOut.write(memCmd(cmd.addr, PAGE_SIZE));
			cmd.addr += PAGE_SIZE;
			cmd.len -= PAGE_SIZE;
			metaOut.write(boundCheckMeta(PAGE_SIZE, true));
		}
		else*/
		{
			cmdOut.write(memCmd(cmd.addr, cmd.len));
			bc_state = CMD;
		}
		break;
	}
}

void pkg_split(	hls::stream<boundCheckMeta>&	metaIn,
				hls::stream<net_axis<512> >&	dataIn,
				hls::stream<net_axis<512> >&	dataOut)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE=off

	enum pbcStateType{PKG_FIRST, PKG_SECOND, LAST};
	static pbcStateType pbc_state = PKG_FIRST;
	static boundCheckMeta meta;
	static bool metaLoaded = false;
	net_axis<512> currWord;
	net_axis<512> sendWord;
	static net_axis<512> prevWord;

	switch (pbc_state)
	{
	/*case META:
		if (!metaIn.empty())
		{
			metaIn.read(meta);
			pbc_state = PKG_FIRST;
			/*if (meta.isSplit)
			{
				pbc_state = PKG_SPLIT;
			}
			else
			{
				pbc_state = PKG;
			}*//*
		}
		break;*/
	case PKG_FIRST:
		if (!dataIn.empty() && (!metaIn.empty() || metaLoaded))
		{
			if (!metaLoaded)
			{
				metaIn.read(meta);
				metaLoaded = true;
			}
			dataIn.read(currWord);
			sendWord.data = currWord.data;
			sendWord.keep = currWord.keep;
			sendWord.last = 0;

			if (meta.length <= 64)
			{
				switch (meta.length)
				{
				/*case 64:
					sendWord.keep = 0xFFFFFFFFFFFFFFFFFF;
					break;*/
				case 56:
					sendWord.keep = 0xFFFFFFFFFFFFFF;
					break;
				case 48:
					sendWord.keep = 0xFFFFFFFFFFFF;
					break;
				case 40:
					sendWord.keep = 0xFFFFFFFFFF;
					break;
				case 32:
					sendWord.keep = 0xFFFFFFFF;
					break;
				case 24:
					sendWord.keep = 0xFFFFFF;
					break;
				case 16:
					sendWord.keep = 0xFFFF;
					break;
				case 8:
					sendWord.keep = 0xFF;
					break;
				}
				sendWord.last = 1;
			}

			dataOut.write(sendWord);
			prevWord.data = currWord.data;
			prevWord.keep = currWord.keep;
			if (meta.length > 64)
			{
				meta.length -= 64;
			}
			else
			{
				if (!meta.isSplit)
				{
					metaLoaded = false;
					//pbc_state = META;
				}
				else
				{
					if (currWord.last)
					{
						pbc_state = LAST;
					}
					else
					{
						pbc_state = PKG_SECOND;
					}
				}
			}
		}
		break;
	case PKG_SECOND:
		if (!dataIn.empty())
		{
			dataIn.read(currWord);
			switch (meta.length)
			{
			case 56:
				sendWord.data(63, 0) = prevWord.data(511, 448);
				sendWord.data(511, 64) = currWord.data(447, 0);
				sendWord.keep(7, 0) = prevWord.keep(63, 56);
				sendWord.keep(63, 8) = currWord.keep(55, 0);
				sendWord.last = (currWord.keep[56] == 0);
				break;
			case 48:
				sendWord.data(127, 0) = prevWord.data(511, 384);
				sendWord.data(511, 128) = currWord.data(383, 0);
				sendWord.keep(15, 0) = prevWord.keep(63, 48);
				sendWord.keep(63, 16) = currWord.keep(47, 0);
				sendWord.last = (currWord.keep[48] == 0);
				break;
			case 40:
				sendWord.data(191, 0) = prevWord.data(511, 320);
				sendWord.data(511, 192) = currWord.data(319, 0);
				sendWord.keep(23, 0) = prevWord.keep(63, 40);
				sendWord.keep(63, 24) = currWord.keep(39, 0);
				sendWord.last = (currWord.keep[40] == 0);
				break;
			case 32:
				sendWord.data(255, 0) = prevWord.data(511, 256);
				sendWord.data(511, 256) = currWord.data(255, 0);
				sendWord.keep(31, 0) = prevWord.keep(63, 32);
				sendWord.keep(63, 32) = currWord.keep(31, 0);
				sendWord.last = (currWord.keep[32] == 0);
				break;
			case 24:
				sendWord.data(319, 0) = prevWord.data(511, 192);
				sendWord.data(511, 320) = currWord.data(191, 0);
				sendWord.keep(39, 0) = prevWord.keep(63, 24);
				sendWord.keep(63, 40) = currWord.keep(23, 0);
				sendWord.last = (currWord.keep[24] == 0);
				break;
			case 16:
				sendWord.data(383, 0) = prevWord.data(511, 128);
				sendWord.data(511, 384) = currWord.data(127, 0);
				sendWord.keep(47, 0) = prevWord.keep(63, 16);
				sendWord.keep(63, 48) = currWord.keep(15, 0);
				sendWord.last = (currWord.keep[16] == 0);
				break;
			case 8:
				sendWord.data(447, 0) = prevWord.data(511, 64);
				sendWord.data(511, 448) = currWord.data(63, 0);
				sendWord.keep(55, 0) = prevWord.keep(63, 8);
				sendWord.keep(63, 56) = currWord.keep(7, 0);
				sendWord.last = (currWord.keep[8] == 0);
				break;
			default:
				sendWord = currWord;
				break;
			}//switch

			dataOut.write(sendWord);
			prevWord.data = currWord.data;
			prevWord.keep = currWord.keep;
			if (sendWord.last)
			{
				metaLoaded = false;
				pbc_state = PKG_FIRST;
			}
			else
			{
				if (currWord.last)
				{
					pbc_state = LAST;
				}
			}
		}
		break;
	case LAST:
		switch (meta.length)
		{
		case 56:
			sendWord.data(63, 0) = prevWord.data(511, 448);
			sendWord.data(511, 64) = 0;
			sendWord.keep(7, 0) = prevWord.keep(63, 56);
			sendWord.keep(63, 8) = 0;
			break;
		case 48:
			sendWord.data(127, 0) = prevWord.data(511, 384);
			sendWord.data(511, 128) = 0;
			sendWord.keep(15, 0) = prevWord.keep(63, 48);
			sendWord.keep(63, 16) = 0;
			break;
		case 40:
			sendWord.data(191, 0) = prevWord.data(511, 320);
			sendWord.data(511, 192) = 0;
			sendWord.keep(23, 0) = prevWord.keep(63, 40);
			sendWord.keep(63, 24) = 0;
			break;
		case 32:
			sendWord.data(255, 0) = prevWord.data(511, 256);
			sendWord.data(511, 256) = 0;
			sendWord.keep(31, 0) = prevWord.keep(63, 32);
			sendWord.keep(63, 32) = 0;
			break;
		case 24:
			sendWord.data(319, 0) = prevWord.data(511, 192);
			sendWord.data(511, 320) = 0;
			sendWord.keep(39, 0) = prevWord.keep(63, 24);
			sendWord.keep(63, 40) = 0;
			break;
		case 16:
			sendWord.data(383, 0) = prevWord.data(511, 128);
			sendWord.data(511, 384) = 0;
			sendWord.keep(47, 0) = prevWord.keep(63, 16);
			sendWord.keep(63, 48) = 0;
			break;
		case 8:
			sendWord.data(447, 0) = prevWord.data(511, 64);
			sendWord.data(511, 448) = 0;
			sendWord.keep(55, 0) = prevWord.keep(63, 8);
			sendWord.keep(63, 56) = 0;
			break;
		}//switch
		sendWord.last = 1;
		dataOut.write(sendWord);
		metaLoaded = false;
		pbc_state = PKG_FIRST;
		break;
	}//switch
}



void mem_write_cmd_page_boundary_check_512(	hls::stream<memCmd>&			cmdIn,
											hls::stream<net_axis<512> >&	dataIn,
											hls::stream<memCmd>&			cmdOut,
											hls::stream<net_axis<512> >&	dataOut,
											ap_uint<48>						regBaseVaddr)
{
	#pragma HLS DATAFLOW disable_start_propagation
	#pragma HLS INTERFACE ap_ctrl_none port=return

	#pragma HLS INTERFACE axis register port=cmdIn name=s_axis_cmd
	#pragma HLS INTERFACE axis register port=cmdOut name=m_axis_cmd
	#pragma HLS INTERFACE axis register port=dataIn name=s_axis_data
	#pragma HLS INTERFACE axis register port=dataOut name=m_axis_data
	#pragma HLS DATA_PACK variable=cmdIn
	#pragma HLS DATA_PACK variable=cmdOut
	#pragma HLS INTERFACE ap_none port=regBaseVaddr

	static hls::stream<internalCmd> pageOffsetFifo("pageOffsetFifo");
	static hls::stream<boundCheckMeta> metaFifo("metaFifo");
	#pragma HLS stream depth=2 variable=pageOffsetFifo
	#pragma HLS stream depth=4 variable=metaFifo
	#pragma HLS DATA_PACK variable=pageOffsetFifo
	#pragma HLS DATA_PACK variable=metaFifo

	calculate_page_offset(cmdIn, pageOffsetFifo, regBaseVaddr);
	boundary_check(pageOffsetFifo, cmdOut, metaFifo);
	pkg_split(metaFifo, dataIn, dataOut);

}
