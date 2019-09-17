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

int main()
{

	stream<memCmd>			cmdIn0("cmdIn0");
	stream<net_axis<512> >	dataIn0("dataIn0");
	stream<memCmd>			cmdIn1("cmdIn1");
	stream<net_axis<512> >	dataIn1("dataIn1");
	stream<memCmd>			cmdOut("cmdOut");
	stream<net_axis<512> >	dataOut("dataOut");


	int count = 0;
	net_axis<512> dummyWord;
	dummyWord.data = 0xABCDEFABCDEF;
	dummyWord.keep = 0xffffffff;
	dummyWord.last = 0x0;

	while (count < 1000)
	{
		if (count == 10)
		{
			cmdIn0.write(memCmd(0xFFAA, 64));
			cmdIn1.write(memCmd(0xFFBB, 16));
		}
		if (count == 12)
		{
			dataIn0.write(dummyWord);
			dummyWord.last = 0x1;
			dataIn0.write(dummyWord);
			dummyWord.keep = 0xffff;
			dataIn1.write(dummyWord);
		}
		mem_cmd_data_merger_512(	cmdIn0,
								dataIn0,
								cmdIn1,
								dataIn1,
								cmdOut,
								dataOut);
		count++;
	}

	memCmd cmd;
	std::cout << "[CMD]" << std::endl;
	while (!cmdOut.empty())
	{
		cmdOut.read(cmd);
	}

	net_axis<512> outWord;
	std::cout << "[DATA]" << std::endl;
	while (!dataOut.empty())
	{
		dataOut.read(outWord);
		printLE(std::cout, outWord);
		std::cout << std::endl;
	}

	return 0;
}
