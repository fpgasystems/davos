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
   programDescription.add_options()("numConn,c", boost::program_options::value<unsigned int>(), "Number of memory accesses")
                                    ("wordCount,w", boost::program_options::value<unsigned int>(), "Lenght of the chunks")
                                    ("packetGap,g", boost::program_options::value<unsigned int>(), "Number of cycles between iperf packets")
                                    ("time,t", boost::program_options::value<unsigned int>(), "Time in seconds")
                                    ("run,r", boost::program_options::value<bool>(), "run")
                                    ("dualMode", boost::program_options::value<bool>(), "is write");

   boost::program_options::variables_map commandLineArgs;
   boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
   boost::program_options::notify(commandLineArgs);
   
   fpga::Fpga::setNodeId(0);
   fpga::Fpga::initializeMemory();

   fpga::FpgaController* controller = fpga::Fpga::getController();


   uint32_t numConnections = 1;
   uint32_t wordCount = 10;
   uint32_t packetGap = 0;
   uint64_t timeInSeconds = 10;
   bool dualModeEn = false;
   bool runIt = false;

   if (commandLineArgs.count("numConn") > 0) {
      numConnections = commandLineArgs["numConn"].as<unsigned int>();
   }
   if (commandLineArgs.count("wordCount") > 0) {
      wordCount = commandLineArgs["wordCount"].as<unsigned int>();
   }
   if (commandLineArgs.count("packetGap") > 0) {
      packetGap = commandLineArgs["packetGap"].as<unsigned int>();
   }
   if (commandLineArgs.count("time")) {
      timeInSeconds = commandLineArgs["time"].as<unsigned int>();
   }
   if (commandLineArgs.count("run") > 0) {
      runIt = commandLineArgs["run"].as<bool>();
   }
   if (commandLineArgs.count("dualMode") > 0) {
      dualModeEn = commandLineArgs["dualMode"].as<bool>();
   }

   //set ip address
   controller->setIpAddr(0x0B01D4D1);
   controller->setBoardNumber(4);
   //Arp lookup??

   controller->setIperfAddress(0, 0x0B01D414);
   controller->setIperfAddress(1, 0x0B01D414);
   controller->setIperfAddress(2, 0x0B01D414);
   controller->setIperfAddress(3, 0x0B01D414);
   controller->setIperfAddress(4, 0x0B01D414);
   controller->setIperfAddress(5, 0x0B01D414);
   controller->setIperfAddress(6, 0x0B01D414);
   controller->setIperfAddress(7, 0x0B01D414);
   controller->setIperfAddress(8, 0x0B01D414);
   controller->setIperfAddress(9, 0x0B01D414);


   uint64_t timeInCycles = (uint64_t) (((double)timeInSeconds) * 1000.0 * 1000.0 * 1000.0 / 6.4);
   uint32_t timeInHectoSeconds = (timeInSeconds * 100) * (-1);
   std::cout << "time in cycles: " << std::dec << timeInCycles << std::endl;
   std::cout << "time in hecto: " << std::dec << timeInHectoSeconds << std::endl;
   if (runIt) {
      uint64_t runCycles = controller->runIperfBenchmark(dualModeEn, numConnections, wordCount, packetGap, timeInHectoSeconds, timeInCycles);

      std::cout << std::dec << "Time[s]: " << ((double) runCycles) * 6.4 / 1000.0 / 1000.0 / 1000.0 << std::endl;
   }


   
	fpga::Fpga::getController()->printDebugRegs();
   controller->printNetStatsRegs();
   /*fpga::Fpga::getController()->printDmaStatsRegs();
   fpga::Fpga::getController()->printDdrStatsRegs(0);
   fpga::Fpga::getController()->printDdrStatsRegs(1);*/

   fpga::Fpga::clear();

	return 0;

}

