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
#include "../mock_dma/mock_dma.hpp"
#include <random>


int main()
{
   hls::stream<memCmd>			cmdIn0("cmdIn0");
   hls::stream<memCmd>			cmdIn1("cmdIn1");
   hls::stream<memCmd>			cmdOut("cmdOut");
   hls::stream<net_axis<512> > dataIn("dataIn");
   hls::stream<net_axis<512> > dataOut0("dataOut0");
   hls::stream<net_axis<512> > dataOut1("dataOut1");
   ap_uint<64>				regbaseVaddr = 0;


   std::vector<uint32_t> slave0ExpectedLength;
   std::vector<uint32_t> slave1ExpectedLength;

   std::default_random_engine generator;
   std::uniform_int_distribution<int> distribution(1, 8388608);

   int count = 0;
   while (count < 10000000)
   {
      if (count == 5)
      {
         cmdIn1.write(memCmd(1024, 4194304));
         slave1ExpectedLength.push_back(4194304);
      }
      if (count == 6)
      {
         cmdIn0.write(memCmd(0x7f996f9ffff8, 64));
         slave0ExpectedLength.push_back(64);
      }
      if (count >= 10 && count< 100)
      {
         uint32_t addr = distribution(generator);
         uint32_t length = distribution(generator);
         if (count % 2 == 0)
         {
            cmdIn0.write(memCmd(addr, length));
            slave0ExpectedLength.push_back(length);
         }
         else
         {
            cmdIn1.write(memCmd(addr, length));
            slave1ExpectedLength.push_back(length);
         }
      }

      mem_read_cmd_merger_512(cmdIn0,
										cmdIn1,
										cmdOut,
										dataIn,
										dataOut0,
										dataOut1,
										regbaseVaddr);

      mock_dma(cmdOut, dataIn);

      count++;
   }

   uint32_t currLength = 0;
   bool correct = true;
   while (!dataOut0.empty())
   {
      net_axis<512> word = dataOut0.read();
      std::cout << "dataOut0: ";
      printLE(std::cout, word);
      std::cout << std::endl;
      currLength += keepToLen<512>(word.keep);
      if (word.last)
      {
         uint32_t expectedLength = slave0ExpectedLength.front();
         slave0ExpectedLength.erase(slave0ExpectedLength.begin());
         correct = (correct && (currLength == expectedLength));
         currLength = 0;
      }
   }
   while (!dataOut1.empty())
   {
      net_axis<512> word = dataOut1.read();
      std::cout << "dataOut1: ";
      printLE(std::cout, word);
      std::cout << std::endl;
      currLength += keepToLen<512>(word.keep);
      if (word.last)
      {
         uint32_t expectedLength = slave1ExpectedLength.front();
         slave1ExpectedLength.erase(slave1ExpectedLength.begin());
         correct = (correct && (currLength == expectedLength));
         currLength = 0;
      }
      else
      {
         correct = correct && (word.keep = 0xFFFFFFFFFFFFFFFF);
         assert(word.keep = 0xFFFFFFFFFFFFFFFF);
      }

   }

   if (correct)
   {
      std::cout << "[TEST] PASSED" << std::endl;
   }
   else
   {
      std::cout << "[TEST] FAILED" << std::endl;
   }
   
  

   return (correct) ? 0 : -1;
}