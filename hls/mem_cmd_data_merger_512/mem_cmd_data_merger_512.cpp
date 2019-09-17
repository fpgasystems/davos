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
#include "mem_cmd_data_merger_512.hpp"


void mem_cmd_data_merger_512(	hls::stream<memCmd>&			cmdIn0,
							hls::stream<net_axis<512> >&	dataIn0,
							hls::stream<memCmd>&			cmdIn1,
							hls::stream<net_axis<512> >&	dataIn1,
							hls::stream<memCmd>&			cmdOut,
							hls::stream<net_axis<512> >&	dataOut)
{
#pragma HLS inline off
#pragma HLS pipeline II=1
#pragma HLS INTERFACE ap_ctrl_none port=return

	#pragma HLS INTERFACE axis register port=cmdIn0 name=s_axis_cmd0
	#pragma HLS INTERFACE axis register port=cmdIn1 name=s_axis_cmd1
	#pragma HLS INTERFACE axis register port=cmdOut name=m_axis_cmd
	#pragma HLS INTERFACE axis register port=dataIn0 name=s_axis_data0
	#pragma HLS INTERFACE axis register port=dataIn1 name=s_axis_data1
	#pragma HLS INTERFACE axis register port=dataOut name=m_axis_data
	#pragma HLS DATA_PACK variable=cmdIn0
	#pragma HLS DATA_PACK variable=cmdIn1
	#pragma HLS DATA_PACK variable=cmdOut

	enum mrpStateType{IDLE, FWD0, FWD1};
	static mrpStateType state = IDLE;

	net_axis<512> currWord;

	switch (state)
	{
	case IDLE:
		if (!cmdIn0.empty() && !dataIn0.empty())
		{
			cmdOut.write(cmdIn0.read());
			dataIn0.read(currWord);
			dataOut.write(currWord);
			if (!currWord.last)
			{
				state = FWD0;
			}
		}
		else if (!cmdIn1.empty() && !dataIn1.empty())
		{
			cmdOut.write(cmdIn1.read());
			dataIn1.read(currWord);
			dataOut.write(currWord);
			if (!currWord.last)
			{
				state = FWD1;
			}
		}
		break;
	case FWD0:
		if (!dataIn0.empty())
		{
			dataIn0.read(currWord);
			dataOut.write(currWord);
			if (currWord.last)
			{
				state = IDLE;
			}
		}
		break;
	case FWD1:
		if (!dataIn1.empty())
		{
			dataIn1.read(currWord);
			dataOut.write(currWord);
			if (currWord.last)
			{
				state = IDLE;
			}
		}
		break;
	}//switch
}
