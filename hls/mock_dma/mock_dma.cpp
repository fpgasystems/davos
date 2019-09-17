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
#include "mock_dma.hpp"



void mock_dma(  hls::stream<memCmd>&  s_axis_read_cmd,
                hls::stream<net_axis<512> >&    m_axis_read_data)
{
#pragma HLS PIPELINE II=1
#pragma HLS INTERFACE ap_ctrl_none register port=return

	#pragma HLS resource core=AXI4Stream variable=s_axis_read_cmd metadata="-bus_bundle s_axis_read_cmd"
	#pragma HLS resource core=AXI4Stream variable=m_axis_read_data metadata="-bus_bundle m_axis_read_data"
	#pragma HLS DATA_PACK variable=s_axis_read_cmd

    static ap_uint<1> state = 0;
    static ap_uint<32> length;

    switch (state)
    {
    case 0:
        if (!s_axis_read_cmd.empty())
        {
            memCmd cmd = s_axis_read_cmd.read();
            std::cout << "Reading address: " << std::hex << cmd.addr << ", length: " << std::dec << cmd.len << std::endl;
            length = cmd.len;
            state = 1;
        }
        break;
    case 1:
        net_axis<512> word;
        for (int i = 0; i < 64; i++)
        {
            #pragma HLS UNROLL
            word.data(i*8+7, i*8) = 0xBEEF + i;
            word.keep[i] = (length > i);
        }
        word.last = 0;
        if (length <= 64)
        {
            word.last = 1;
            state = 0;
        }
        m_axis_read_data.write(word);
        length -= 64;
        break;
    } //switch
}

