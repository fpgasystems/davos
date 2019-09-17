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
#include "FpgaController.h"

#include <cstring>
#include <thread>
#include <chrono>
              
//#define PRINT_DEBUG

using namespace std::chrono_literals;

namespace fpga {

std::mutex FpgaController::ctrl_mutex;
std::mutex FpgaController::btree_mutex;
std::atomic_uint FpgaController::cmdCounter = ATOMIC_VAR_INIT(0);
uint64_t FpgaController::mmTestValue;

FpgaController::FpgaController(int fd, int byfd)
{
   //open control device
   m_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
   //open bypass device
   by_base =  mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, byfd, 0);
}

FpgaController::~FpgaController()
{
   if (munmap(m_base, MAP_SIZE) == -1)
   {
      std::cerr << "Error on unmap of control device" << std::endl;
   }

   if (munmap(by_base, MAP_SIZE) == -1)
   {
      std::cerr << "Error on unmap of bypass device" << std::endl;
   }
}

void FpgaController::writeTlb(unsigned long vaddr, unsigned long paddr, bool isBase)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
#ifdef PRINT_DEBUG
   printf("Writing tlb mapping\n");fflush(stdout);
#endif
   writeReg(dmaCtrlAddr::TLB, (uint32_t) vaddr);
   writeReg(dmaCtrlAddr::TLB, (uint32_t) (vaddr >> 32));
   writeReg(dmaCtrlAddr::TLB, (uint32_t) paddr);
   writeReg(dmaCtrlAddr::TLB, (uint32_t) (paddr >> 32));
   writeReg(dmaCtrlAddr::TLB, (uint32_t) isBase);
#ifdef PRINT_DEBUG
   printf("done\n");fflush(stdout);
#endif
}

uint64_t FpgaController::runDmaSeqWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength)
{
   return runDmaBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, 0, memoryOp::WRITE);
}

uint64_t FpgaController::runDmaSeqReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength)
{
   return runDmaBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, 0, memoryOp::READ);
}

uint64_t FpgaController::runDmaRandomWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint32_t strideLength)
{
   return runDmaBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, strideLength, memoryOp::WRITE);
}

uint64_t FpgaController::runDmaRandomReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint32_t strideLength)
{
   return runDmaBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, strideLength, memoryOp::READ);
}

uint64_t FpgaController::runDmaBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint32_t strideLength, memoryOp op)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
#ifdef PRINT_DEBUG
   printf("Run dma benchmark\n");fflush(stdout);
#endif

   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) baseAddr);
   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) (baseAddr >> 32));
   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) memorySize);
   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) (memorySize >> 32));
   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) numberOfAccesses);
   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) chunkLength);
   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) strideLength);
   writeReg(userCtrlAddr::DMA_BENCH, (uint32_t) op);

   //retrieve number of execution cycles
   
   uint64_t lower = 0;
   uint64_t upper = 0;
   do
   {
      std::this_thread::sleep_for(1s);
      lower = readReg(userCtrlAddr::DMA_BENCH_CYCLES);
      upper = readReg(userCtrlAddr::DMA_BENCH_CYCLES);
   } while (lower == 0);
   return ((upper << 32) | lower);


#ifdef PRINT_DEBUG
   printf("done\n");fflush(stdout);
#endif
}

uint64_t FpgaController::runDramSeqWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint8_t channel)
{
   return runDramBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, 0, memoryOp::WRITE, channel);
}

uint64_t FpgaController::runDramSeqReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint8_t channel)
{
   return runDramBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, 0, memoryOp::READ, channel);
}

uint64_t FpgaController::runDramRandomWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint32_t strideLength, uint8_t channel)
{
   return runDramBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, strideLength, memoryOp::WRITE, channel);
}

uint64_t FpgaController::runDramRandomReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint32_t strideLength, uint8_t channel)
{
   return runDramBenchmark(baseAddr, memorySize, numberOfAccesses, chunkLength, strideLength, memoryOp::READ, channel);
}

uint64_t FpgaController::runDramBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAccesses, uint32_t chunkLength, uint32_t strideLength, memoryOp op, uint8_t channel)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
#ifdef PRINT_DEBUG
   printf("Run dma benchmark\n");fflush(stdout);
#endif

   writeReg(userCtrlAddr::DDR_BENCH, (uint32_t) baseAddr);
   writeReg(userCtrlAddr::DDR_BENCH, (uint32_t) (baseAddr >> 32));
   writeReg(userCtrlAddr::DDR_BENCH, (uint32_t) memorySize);
   writeReg(userCtrlAddr::DDR_BENCH, (uint32_t) (memorySize >> 32));
   writeReg(userCtrlAddr::DDR_BENCH, (uint32_t) numberOfAccesses);
   writeReg(userCtrlAddr::DDR_BENCH, (uint32_t) chunkLength);
   writeReg(userCtrlAddr::DDR_BENCH, (uint32_t) strideLength);
   writeReg(userCtrlAddr::DDR_BENCH, (((uint32_t) channel) << 1) | ((uint32_t) op));

   //retrieve number of execution cycles
   
   uint64_t lower = 0;
   uint64_t upper = 0;
   do
   {
      std::this_thread::sleep_for(1s);
      lower = readReg(userCtrlAddr::DDR_BENCH_CYCLES);
      upper = readReg(userCtrlAddr::DDR_BENCH_CYCLES);
   } while (lower == 0);
   return ((upper << 32) | lower);


#ifdef PRINT_DEBUG
   printf("done\n");fflush(stdout);
#endif
}

uint64_t FpgaController::runIperfBenchmark(bool dualModeEn, uint16_t numConnections, uint8_t wordCounter, uint8_t packetGap, uint32_t timeInHectoSeconds, uint64_t timeInCycles)
{
   //TODO include target address
   uint32_t cmd = (packetGap << 24) | (wordCounter << 16) | ((numConnections & 0x7FFF) << 1) | dualModeEn;

   writeReg(userCtrlAddr::IPERF_BENCH, cmd);
   writeReg(userCtrlAddr::IPERF_BENCH, timeInHectoSeconds);
   writeReg(userCtrlAddr::IPERF_BENCH, (uint32_t) timeInCycles);
   writeReg(userCtrlAddr::IPERF_BENCH, (uint32_t) (timeInCycles >> 32));

   //retrieve number of execution cycles
   
   uint64_t lower = 0;
   uint64_t upper = 0;
   do
   {
      std::this_thread::sleep_for(1s);
      lower = readReg(userCtrlAddr::IPERF_CYCLES);
      upper = readReg(userCtrlAddr::IPERF_CYCLES);
   } while (lower == 0);
   return ((upper << 32) | lower);
}

void FpgaController::setIperfAddress(uint8_t number, uint32_t address)
{
   writeReg(userCtrlAddr::IPERF_ADDR, number);
   writeReg(userCtrlAddr::IPERF_ADDR, address);
}


void FpgaController::setIpAddr(uint32_t addr)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);

   writeReg(netCtrlAddr::IPADDR, addr);
}

void FpgaController::setBoardNumber(uint8_t num)
{
printf("board num\n");
   std::lock_guard<std::mutex> guard(ctrl_mutex);
   writeReg(netCtrlAddr::BOARDNUM, num);
}

void FpgaController::resetDmaReads()
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
   writeReg(dmaCtrlAddr::DMA_READS, uint8_t(1));
}

uint64_t FpgaController::getDmaReads()
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
   uint64_t lower = readReg(dmaCtrlAddr::DMA_READS);
   uint64_t upper = readReg(dmaCtrlAddr::DMA_READS);
   return ((upper << 32) | lower);
}

void FpgaController::resetDmaWrites()
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
   writeReg(dmaCtrlAddr::DMA_WRITES, uint8_t(1));
}

uint64_t FpgaController::getDmaWrites()
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
   uint64_t lower = readReg(dmaCtrlAddr::DMA_WRITES);
   uint64_t upper = readReg(dmaCtrlAddr::DMA_WRITES);
   return ((upper << 32) | lower);
}

void FpgaController::printDebugRegs()
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);

   std::cout << "------------ DEBUG ---------------" << std::endl;
   for (int i = 0; i < numDebugRegs; ++i)
   {
      uint32_t reg = readReg(userCtrlAddr::DEBUG);
      std::cout << RegNames[i] << ": " << std::dec << reg << std::endl;
   }
   std::cout << "----------------------------------" << std::endl;
}

void FpgaController::printDmaStatsRegs()
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);

   std::cout << "------------ DMA STATISTICS ---------------" << std::endl;
   for (int i = 0; i < numDmaStatsRegs; ++i)
   {
      uint32_t reg = readReg(dmaCtrlAddr::STATS);
      std::cout << DmaRegNames[i] << ": " << std::dec << reg << std::endl;
   }
   std::cout << "----------------------------------" << std::endl;
}

void FpgaController::printDdrStatsRegs(uint8_t channel)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);

   std::cout << "------------ DDR" << (uint16_t) channel << " STATISTICS ---------------" << std::endl;
   for (int i = 0; i < numDdrStatsRegs; ++i)
   {
      uint32_t reg = readReg(ddrCtrlAddr::STATS, channel);
      std::cout << "DDR" << (uint16_t) channel << " ";
      std::cout << DdrRegNames[i] << ": " << std::dec << reg << std::endl;
   }
   std::cout << "----------------------------------" << std::endl;
}

void FpgaController::printNetStatsRegs(uint8_t port)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);

   std::cout << "------------ Network" << (uint16_t) port << " STATISTICS ---------------" << std::endl;
   for (int i = 0; i < numNetStatsRegs; ++i)
   {
      uint32_t reg = readReg(netCtrlAddr::STATS, port);
      std::cout << "Net" << (uint16_t) port << " ";
      std::cout << NetRegNames[i] << ": " << std::dec << reg << std::endl;
   }
   std::cout << "----------------------------------" << std::endl;
}


/*void FpgaController::writeReg(ctrlAddr addr, uint8_t value)
{
   volatile uint32_t* wPtr = (uint32_t*) (((uint64_t) m_base) + (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols(value);
   *wPtr = writeVal;
}*/

void FpgaController::writeReg(btreeCtrlAddr addr, uint32_t value)
{
   volatile uint32_t* wPtr = (uint32_t*) (((uint64_t) m_base) + userRegAddressOffset + (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols(value);
   *wPtr = writeVal;
}

void FpgaController::writeReg(userCtrlAddr addr, uint32_t value)
{
   volatile uint32_t* wPtr = (uint32_t*) (((uint64_t) m_base) + userRegAddressOffset + (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols(value);
   *wPtr = writeVal;
}

void FpgaController::writeReg(dmaCtrlAddr addr, uint32_t value)
{
   volatile uint32_t* wPtr = (uint32_t*) (((uint64_t) m_base) + dmaRegAddressOffset +  (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols(value);
   *wPtr = writeVal;
}

void FpgaController::writeReg(netCtrlAddr addr, uint32_t value, uint8_t port)
{
   volatile uint32_t* wPtr = (uint32_t*) (((uint64_t) m_base) + netRegAddressOffset[port] +  (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols(value);
   *wPtr = writeVal;
}


/*void FpgaController::writeReg(ctrlAddr addr, uint64_t value)
{
   uint32_t* wPtr = (uint32_t*) (((uint64_t) m_base) + (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols((uint32_t) value);
   *wPtr = writeVal;
   
   writeVal = htols((uint32_t) (value >> 32));
   *wPtr = writeVal;

}*/

uint32_t FpgaController::readReg(userCtrlAddr addr)
{
   volatile uint32_t* rPtr = (uint32_t*) (((uint64_t) m_base) + userRegAddressOffset  + (uint64_t) ((uint32_t) addr << 5));
  return htols(*rPtr);
}

uint32_t FpgaController::readReg(dmaCtrlAddr addr)
{
   volatile uint32_t* rPtr = (uint32_t*) (((uint64_t) m_base) + dmaRegAddressOffset  + (uint64_t) ((uint32_t) addr << 5));
  return htols(*rPtr);
}

uint32_t FpgaController::readReg(ddrCtrlAddr addr, uint8_t channel)
{
   volatile uint32_t* rPtr = (uint32_t*) (((uint64_t) m_base) + ddrRegAddressOffset[channel]  + (uint64_t) ((uint32_t) addr << 5));
  return htols(*rPtr);
}

uint32_t FpgaController::readReg(netCtrlAddr addr, uint8_t port)
{
   volatile uint32_t* rPtr = (uint32_t*) (((uint64_t) m_base) + netRegAddressOffset[port]  + (uint64_t) ((uint32_t) addr << 5));
  return htols(*rPtr);
}

/*
 * Bypass 
 */
void FpgaController::writeMM(mmCtrlAddr addr, uint64_t value)
{
   volatile uint64_t* wPtr = (uint64_t*) (((uint64_t) by_base) + mmRegAddressOffset + ((uint64_t) addr << 5));
   uint64_t writeVal = htols(value);
   *wPtr = writeVal;
}

uint64_t FpgaController::readMM(mmCtrlAddr addr)
{
   volatile uint64_t* rPtr = (uint64_t*) (((uint64_t) by_base) + mmRegAddressOffset + ((uint64_t) addr << 5));
  return htols(*rPtr);
}

// optwriteReg functions aim to use one 256-bit transaction to write to XDMA-Bypass region 
void FpgaController::optwriteReg(userCtrlAddr addr, uint32_t value)
{
   volatile uint32_t* wPtr = (uint32_t*) (((uint64_t) by_base) + userRegAddressOffset + (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols(value);
   *wPtr = writeVal;
}

void FpgaController::optwriteReg(dmaCtrlAddr addr, uint32_t value)
{
   volatile uint32_t* wPtr = (uint32_t*) (((uint64_t) by_base) + dmaRegAddressOffset +  (uint64_t) ((uint32_t) addr << 5));
   uint32_t writeVal = htols(value);
   *wPtr = writeVal;
}


void FpgaController::optwriteReg(netCtrlAddr addr, __m256i* value, uint8_t port)
{
   volatile uint64_t* wPtr = (uint64_t*) (((uint64_t) by_base) + netRegAddressOffset[port] +  ((uint64_t) addr << 5));

   _mm256_store_si256 ((__m256i *) wPtr, (__m256i) *value);
   _mm_mfence();

}

void FpgaController::optpostCmd(appOpCode op, roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr)
{
  // std::lock_guard<std::mutex> guard(ctrl_mutex);
  // Declare the values to be written :   VAL write_values = {{op, pair->local.qpn, originAddr, targetAddr, size}};

   //Check if not too many outstanding cmds
   while (cmdCounter > (cmdFifoDepth - 10)) {
      cmdCounter = readReg(netCtrlAddr::CMD_OUT);
      if (cmdCounter > (cmdFifoDepth - 10)) {
         std::cout << "cmd fifo full" << std::endl;
         std::this_thread::sleep_for(std::chrono::microseconds(1));
      }
   }

#ifdef JOIN_DEBUG_PRINT
   printf("postCmd, code: %i, originAddr: %lx, size: %u, targetAddr: %lx\n", op, originAddr, size, targetAddr);
#endif
  
   VAL write_values = {uint8_t(op), uint32_t(pair->local.qpn), uint64_t(originAddr), uint64_t(targetAddr), uint32_t(size)};
   optwriteReg(netCtrlAddr::POST, (__m256i*) &write_values);
   
   //update cmd counter atomic operation
   cmdCounter++;

#ifdef IB_DEBUG
   std::cout << std::hex << "local vaddr: " << originAddr << std::endl;
   std::cout << std::hex << "target vaddr: " << targetAddr << std::endl;
   std::cout << std::hex << "length: " << size << std::endl;
   printf("done\n");fflush(stdout);
#endif
}

/*
 * RoCE
 */
void FpgaController::writeContext(roce::QueuePair* pair)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
#ifdef IB_DEBUG
   printf("Writing context\n");
#endif
   writeReg(netCtrlAddr::CTX, (uint8_t) qpState::RESET);
   writeReg(netCtrlAddr::CTX, (uint32_t) pair->local.qpn);
   writeReg(netCtrlAddr::CTX, (uint32_t) pair->remote.psn);
   writeReg(netCtrlAddr::CTX, (uint32_t) pair->local.psn);
   writeReg(netCtrlAddr::CTX, (uint32_t) pair->remote.rkey);
   writeReg(netCtrlAddr::CTX, (uint32_t) pair->remote.vaddr);
   writeReg(netCtrlAddr::CTX, ((uint32_t) (pair->remote.vaddr >> 32)));

#ifdef IB_DEBUG
   printf("done\n");
#endif
}

void FpgaController::writeConnection(roce::QueuePair* pair, int port)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);
#ifdef IB_DEBUG
   printf("Writing connection\n");
#endif
   writeReg(netCtrlAddr::CONN, (uint32_t) pair->local.qpn);
   writeReg(netCtrlAddr::CONN, (uint32_t) pair->remote.qpn);

   uint32_t writeVal = htols(pair->remote.gidToUint(0));
   writeReg(netCtrlAddr::CONN, writeVal);

   writeVal = htols(pair->remote.gidToUint(8));
   writeReg(netCtrlAddr::CONN, writeVal);

   writeVal = htols(pair->remote.gidToUint(16));
   writeReg(netCtrlAddr::CONN, writeVal);
 
   writeVal = htols(pair->remote.gidToUint(24));
   writeReg(netCtrlAddr::CONN, writeVal);

   writeReg(netCtrlAddr::CONN, (uint32_t)port);
#ifdef IB_DEBUG
   printf("done\n");
#endif
}

void FpgaController::postWrite(roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr)
{
  // postCmd(appOpCode::APP_WRITE, pair, originAddr, size, targetAddr);
   optpostCmd(appOpCode::APP_WRITE, pair, originAddr, size, targetAddr);
}

void FpgaController::postRead(roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr)
{
   postCmd(appOpCode::APP_READ, pair, originAddr, size, targetAddr);
}

/*void FpgaController::postPart(roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr)
{
   postCmd(appOpCode::APP_PART, pair, originAddr, size, targetAddr);
}*/

void FpgaController::postCmd(appOpCode op, roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr)
{
   std::lock_guard<std::mutex> guard(ctrl_mutex);

   //Check if not too many outstanding cmds
   while (cmdCounter > (cmdFifoDepth - 10)) {
      cmdCounter = readReg(netCtrlAddr::CMD_OUT);
      if (cmdCounter > (cmdFifoDepth - 10)) {
         std::cout << "cmd fifo full" << std::endl;
         std::this_thread::sleep_for(std::chrono::microseconds(1));
      }
   }

#ifdef JOIN_DEBUG_PRINT
   printf("postCmd, code: %i, originAddr: %lx, size: %u, targetAddr: %lx\n", op, originAddr, size, targetAddr);
#endif
#ifdef LEGACY_POST
   // one writeReg -> one AXI Lite transaction 
   writeReg(netCtrlAddr::POST, (uint32_t)((((uint32_t)op) << 24) | (pair->local.qpn & 0xFFFFFF)));

   writeReg(netCtrlAddr::POST, (uint32_t) (uint64_t) originAddr); //Implies VADDR_HIGH
   writeReg(netCtrlAddr::POST, (uint32_t) (((uint64_t) originAddr) >> 32)); //Implies VADDR_HIGH
   writeReg(netCtrlAddr::POST, (uint32_t) (uint64_t)targetAddr); //Implies VADDR_HIGH
   writeReg(netCtrlAddr::POST, (uint32_t) (((uint64_t) targetAddr) >> 32)); //Implies VADDR_HIGH
   writeReg(netCtrlAddr::POST, size);
#else
   writeReg(netCtrlAddr::POST, (((uint64_t) originAddr) & 0xFFFFFFFC) | (pair->local.qpn & 0x3));
   writeReg(netCtrlAddr::POST, ((((uint64_t) targetAddr) & 0xFFFC) << 16) | (((pair->local.qpn >> 2) & 0x3) << 16) | ((((uint64_t) originAddr) >> 32) & 0xFFFF));
   writeReg(netCtrlAddr::POST, (((uint64_t) targetAddr) >> 16)); 
   writeReg(netCtrlAddr::POST, (uint32_t) (size & 0xFFFFFFF8) | (((uint32_t) op) & 0x7));
#endif
   //update cmd counter
   cmdCounter++;

   #ifdef IB_DEBUG
   std::cout << std::hex << "local vaddr: " << originAddr << std::endl;
   std::cout << std::hex << "local vaddr: " << targetAddr << std::endl;
   std::cout << std::hex << "length: " << size << std::endl;
   printf("done\n");fflush(stdout);
#endif
}

bool FpgaController::doArpLookup(uint32_t ipAddr, uint64_t& macAddr)
{
   writeReg(netCtrlAddr::ARP, ipAddr);
   macAddr = 0;
   return true;
}

} /* namespace fpga */
