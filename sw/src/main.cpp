/*
 * Copyright (c) 2018, Systems Group, ETH Zurich
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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <boost/program_options.hpp>

#include <fpga/Fpga.h>
#include <fpga/FpgaController.h>


int main(int argc, char *argv[]) {

   boost::program_options::options_description programDescription("Allowed options");
   programDescription.add_options()("memorySize,m", boost::program_options::value<unsigned long>(), "Size of the memory region")
                                    ("accesses,a", boost::program_options::value<unsigned int>(), "Number of memory accesses")
                                    ("strideLength,s", boost::program_options::value<unsigned int>(), "Stride length between memory accesses")
                                    ("isWrite,w", boost::program_options::value<bool>(), "is write")
                                    ("testDDR,t", boost::program_options::value<bool>(), "use DDR")
                                    ("ddrChannel,d", boost::program_options::value<unsigned int>(), "DDR channel, default: 0")
                                    ("clockPeriod,p", boost::program_options::value<double>(), "Clock period of the FPGA, default: 4ns");

   boost::program_options::variables_map commandLineArgs;
   boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
   boost::program_options::notify(commandLineArgs);
   
   fpga::Fpga::setNodeId(0);
   fpga::Fpga::initializeMemory();

   fpga::FpgaController* controller = fpga::Fpga::getController();


   uint64_t memorySize   = 4096;
   uint32_t accesses     = 10;
   uint32_t chunkLength  = 64;
   uint32_t strideLength = 0;
   double clockPeriod    = 4;
   bool isWrite          = true;
   bool useDDR           = false;
   uint8_t ddrChannel    = 0;

   if (commandLineArgs.count("memorySize") > 0) {
      memorySize = commandLineArgs["memorySize"].as<unsigned long>();
   }
   if (commandLineArgs.count("accesses") > 0) {
      accesses = commandLineArgs["accesses"].as<unsigned int>();
   }
   if (commandLineArgs.count("chunkLength") > 0) {
      chunkLength = commandLineArgs["chunkLength"].as<unsigned int>();
   }
   if (commandLineArgs.count("strideLength") > 0) {
      strideLength = commandLineArgs["strideLength"].as<unsigned int>();
   }
   if (commandLineArgs.count("clockPeriod") > 0) {
       clockPeriod = commandLineArgs["clockPeriod"].as<double>();
   }
   if (commandLineArgs.count("isWrite") > 0) {
      isWrite = commandLineArgs["isWrite"].as<bool>();
   }
   if (commandLineArgs.count("testDDR") > 0) {
      useDDR = commandLineArgs["testDDR"].as<bool>();
   }
   if (commandLineArgs.count("ddrChannel") > 0) {
      ddrChannel = commandLineArgs["ddrChannel"].as<unsigned int>();
   }
 
   bool isRandom = (strideLength != 0);

   if (isRandom) {
      std::cout << "Random ";
   } else {
      std::cout << "Sequential ";
   }
   if (isWrite) {
      std::cout << "write ";
   } else {
      std::cout << "read ";
   }
   std::cout << "memory size: " << memorySize << ", number of accesses: " << accesses << ", length per access: " << chunkLength;
   if (isRandom) {
      std::cout << ", stride length: " << strideLength;
   }
   std::cout << std::endl;

   void* baseAddr = fpga::Fpga::allocate(memorySize);


   uint64_t cycles = 0;
   if (!useDDR)
   {
      if (!isRandom) {
         if (isWrite) {
            cycles = controller->runDmaSeqWriteBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength);
         } else {
            cycles = controller->runDmaSeqReadBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength);
         }
      } else {
         if (isWrite) {
            cycles = controller->runDmaRandomWriteBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength, strideLength);
         } else {
            cycles = controller->runDmaRandomReadBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength, strideLength);
         }
      }
   }
   else //DDR
   {
      if (!isRandom) {
         if (isWrite) {
            cycles = controller->runDramSeqWriteBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength, ddrChannel);
         } else {
            cycles = controller->runDramSeqReadBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength, ddrChannel);
         }
      } else {
         if (isWrite) {
            cycles = controller->runDramRandomWriteBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength, strideLength, ddrChannel);
         } else {
            cycles = controller->runDramRandomReadBenchmark((uint64_t) baseAddr, memorySize, accesses, chunkLength, strideLength, ddrChannel);
         }
      }
   }

   std::cout << "Execution cycles: " << cycles << std::endl;
   uint64_t transferSize = ((uint64_t) accesses) * ((uint64_t) chunkLength);
   double transferSizeGB  = ((double) transferSize) / 1024.0 / 1024.0 / 1024.0;
   double tp  =  transferSizeGB / ((double) (clockPeriod*cycles) / 1000.0 / 1000.0 / 1000.0);
   std::cout << std::fixed << "Transfer size [GiB]: " << transferSizeGB << std::endl;
   std::cout << std::fixed << "Throughput[GiB/s]: " << tp << std::endl;
   std::cout << std::fixed << "#" << memorySize << "\t" << transferSizeGB << "\t" << chunkLength << "\t" << strideLength << "\t" << cycles << "\t" << tp << std::endl;

	fpga::Fpga::getController()->printDebugRegs();
   fpga::Fpga::getController()->printDmaStatsRegs();
   fpga::Fpga::getController()->printDdrStatsRegs(0);
   fpga::Fpga::getController()->printDdrStatsRegs(1);

   fpga::Fpga::free(baseAddr);
   fpga::Fpga::clear();

	return 0;

}

