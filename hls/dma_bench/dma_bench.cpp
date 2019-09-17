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
#include "dma_bench.hpp"


void cmd_generator(	hls::stream<bool>& startSignal,
					hls::stream<memCmd>& m_axis_read_cmd,
					hls::stream<memCmd>& m_axis_write_cmd,
					ap_uint<64> regBaseAddr,
					ap_uint<64> memorySize,
					ap_uint<32>	numberOfAccesses,
					ap_uint<32> chunkLength,
					ap_uint<32> strideLength,
					ap_uint<1>	isWrite,
					ap_uint<1> start)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	enum cmdStateType{IDLE, WRITE_CMD, READ_CMD};
	static cmdStateType state = IDLE;
	static bool isRandom = false;
	static ap_uint<64> currentAddress;
	static ap_uint<32> count;

	switch (state)
	{
	case IDLE:
		if (start && !startSignal.full())
		{
			isRandom = (strideLength != 0);
			currentAddress = regBaseAddr;
			count = 0;
			startSignal.write(1);
			if (isWrite)
			{
				state = WRITE_CMD;
			}
			else
			{
				state = READ_CMD;
			}
		}
		break;
	case WRITE_CMD:
		m_axis_write_cmd.write(memCmd(currentAddress, chunkLength));
		if (!isRandom)
		{
			currentAddress += chunkLength;
		}
		else
		{
			currentAddress += strideLength;
		}
		if (currentAddress+chunkLength > regBaseAddr+memorySize)
		{
			currentAddress = regBaseAddr;
		}
		count++;
		if (count == numberOfAccesses)
		{
			state = IDLE;
		}
		break;
	case READ_CMD:
		m_axis_read_cmd.write(memCmd(currentAddress, chunkLength));
		if (!isRandom)
		{
			currentAddress += chunkLength;
		}
		else
		{
			currentAddress += strideLength;
		}
		if (currentAddress+chunkLength > regBaseAddr+memorySize)
		{
			currentAddress = regBaseAddr;
		}
		count++;
		if (count == numberOfAccesses)
		{
			state = IDLE;
		}
		break;
	}//switch
}

void data_generator(hls::stream<bool>& writeDoneSignal,
					hls::stream<net_axis<512> >& m_axis_write_data,
					ap_uint<32>	numberOfAccesses,
					ap_uint<32> chunkLength,
					ap_uint<1>	isWrite,
					ap_uint<1>	start)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	static ap_uint<1> state = 0;
	static ap_uint<32> remainingLength = 0;
	static ap_uint<32> count = 0;
	net_axis<512> sendWord;

	switch (state)
	{
	case 0:
		if (start && isWrite)
		{
			remainingLength = chunkLength;
			count = 0;
			state = 1;
		}
		break;
	case 1:
		for (int i = 0; i < 64; ++i)
		{
#pragma HLS unroll
			sendWord.data(i*8+7,i*8) = count+i;
			if (remainingLength > i)
			{
				sendWord.keep[i] = 0x1;
			}
		}
		sendWord.last = (remainingLength <= 64);
		remainingLength -= 64;
		m_axis_write_data.write(sendWord);
		if (sendWord.last)
		{
			count++;
			remainingLength = chunkLength;
		}
		if (count == numberOfAccesses)
		{
			writeDoneSignal.write(1);
			state = 0;
		}
		break;
	}//switch

}

void data_consumer(	hls::stream<bool>& readDoneSignal,
					hls::stream<net_axis<512> >& s_axis_read_data,
					ap_uint<32>	numberOfAccesses,
					ap_uint<1> start,
					ap_uint<1> isWrite)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	static ap_uint<1> state = 0;
	static ap_uint<32> count = 0;
	net_axis<512> currWord;

	switch (state)
	{
	case 0:
		if (start && !isWrite)
		{
			count = 0;
			state = 1;
		}
		break;
	case 1:
		if (!s_axis_read_data.empty())
		{
			s_axis_read_data.read(currWord);
			if (currWord.last)
			{
				count++;
			}
			if (count == numberOfAccesses)
			{
				readDoneSignal.write(1);
				state = 0;
			}
		}
		break;
	}//switch
}

void clock(	hls::stream<bool>& startSignal,
			hls::stream<bool>& readDoneSignal,
			hls::stream<bool>& writeDoneSignal,
			ap_uint<64>&		regExecutionCycles)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	static ap_uint<64> cycle_counter;
	static bool running = false;

	if (running)
	{
		cycle_counter++;
	}
	if (!startSignal.empty())
	{
		startSignal.read();
		running = true;
		cycle_counter = 0;
	}
	if (!readDoneSignal.empty())
	{
		readDoneSignal.read();
		running = false;
		regExecutionCycles = cycle_counter;
	}
	if (!writeDoneSignal.empty())
	{
		writeDoneSignal.read();
		running = false;
		regExecutionCycles = cycle_counter;
	}
}



void dma_bench(	hls::stream<memCmd>& m_axis_read_cmd,
				hls::stream<memCmd>& m_axis_write_cmd,
				hls::stream<net_axis<512> >& m_axis_write_data,
				hls::stream<net_axis<512> >& s_axis_read_data,
				ap_uint<64> regBaseAddr,
				ap_uint<64> memorySize,
				ap_uint<32>	numberOfAccesses,
				ap_uint<32> chunkLength,
				ap_uint<32> strideLength,
				ap_uint<1>	isWrite,
				ap_uint<1>  start,
				ap_uint<64>&		regExecutionCycles)
{
	#pragma HLS DATAFLOW disable_start_propagation
	#pragma HLS INTERFACE ap_ctrl_none port=return


	#pragma HLS INTERFACE axis register port=m_axis_read_cmd
	#pragma HLS INTERFACE axis register port=m_axis_write_cmd
	#pragma HLS INTERFACE axis register port=m_axis_write_data
	#pragma HLS INTERFACE axis register port=s_axis_read_data
	#pragma HLS DATA_PACK variable=m_axis_read_cmd
	#pragma HLS DATA_PACK variable=m_axis_write_cmd

	#pragma HLS INTERFACE ap_stable register port=regBaseAddr
	#pragma HLS INTERFACE ap_stable register port=memorySize
	#pragma HLS INTERFACE ap_stable register port=numberOfAccesses
	#pragma HLS INTERFACE ap_stable register port=chunkLength
	#pragma HLS INTERFACE ap_stable register port=strideLength
	#pragma HLS INTERFACE ap_stable register port=isWrite
	#pragma HLS INTERFACE ap_stable register port=start

	#pragma HLS INTERFACE ap_vld port=regExecutionCycles



	static hls::stream<bool> startSignal("startSignal");
	static hls::stream<bool> readDoneStream("readDoneStream");
	static hls::stream<bool> writeDoneStream("writeDoneStream");
	#pragma HLS STREAM variable=startSignal depth=2
	#pragma HLS STREAM variable=readDoneStream depth=2
	#pragma HLS STREAM variable=writeDoneStream depth=2


	cmd_generator(	startSignal,
					m_axis_read_cmd,
					m_axis_write_cmd,
					regBaseAddr,
					memorySize,
					numberOfAccesses,
					chunkLength,
					strideLength,
					isWrite,
					start);
	data_generator(writeDoneStream, m_axis_write_data, numberOfAccesses, chunkLength, start,isWrite);
	//TODO for MIG check write status
	data_consumer(readDoneStream, s_axis_read_data, numberOfAccesses, start, isWrite);

	clock(startSignal, readDoneStream, writeDoneStream, regExecutionCycles);
}
