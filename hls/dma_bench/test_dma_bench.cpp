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


int main ()
{
	hls::stream<memCmd> m_axis_read_cmd("m_axis_read_cmd");
	hls::stream<memCmd> m_axis_write_cmd("m_axis_write_cmd");
	hls::stream<net_axis<512> > m_axis_write_data("m_axis_write_data");
	hls::stream<net_axis<512> > s_axis_read_data("s_axis_read_data");
	ap_uint<64> regBaseAddr = 0;
	ap_uint<64> memorySize = 1024*1024*1024;
	ap_uint<32>	numberOfAccesses = 100;
	ap_uint<32> chunkLength = 128;
	ap_uint<32> strideLength = 4096;
	ap_uint<1>	isWrite = 1;
	ap_uint<1> start;
	ap_uint<64> executionCycles = 0;


	int count = 0;
	while (count < 5000)
	{
		start = (count == 10);

		dma_bench(	m_axis_read_cmd,
					m_axis_write_cmd,
					m_axis_write_data,
					s_axis_read_data,
					regBaseAddr,
					memorySize,
					numberOfAccesses,
					chunkLength,
					strideLength,
					isWrite,
					start,
					executionCycles);
		count++;
	}

	memCmd cmd;
	std::cout << "READ CMDs: " << std::endl;
	int cmdCount = 0;
	while (!m_axis_read_cmd.empty())
	{
		m_axis_read_cmd.read(cmd);
		std::cout << "address: " << std::hex << cmd.addr << ", length: " << std::dec << cmd.len << std::endl;
		cmdCount++;
	}
	std::cout << std::dec << "read command count: " << cmdCount << std::endl;

	std::cout << "WRITE CMDs: " << std::endl;
	cmdCount = 0;
	while (!m_axis_write_cmd.empty())
	{
		m_axis_write_cmd.read(cmd);
		std::cout << "address: " << std::hex << cmd.addr << ", length: " << std::dec << cmd.len << std::endl;
		cmdCount++;
	}
	std::cout << std::dec << "write command count: " << cmdCount << std::endl;


	net_axis<512> word;
	std::cout << "WRITE DATA: " << std::endl;
	int pkgCount = 0;
	while (!m_axis_write_data.empty())
	{
		m_axis_write_data.read(word);
		printLE(std::cout, word);
		std::cout << std::endl;
		if (word.last)
			pkgCount++;
	}
	std::cout << std::dec << "packet count: " << pkgCount << std::endl;

	std::cout << std::dec << "Execution cycles: " << executionCycles << std::endl;

	return 0;
}
