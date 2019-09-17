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
#ifndef FPGA_CONTROLLER_HPP
#define FPGA_CONTROLLER_HPP

#include <stdio.h>
#include <unistd.h>
#include <byteswap.h>
#include <errno.h>
#include <iostream>
#include <fcntl.h>
#include <inttypes.h>
#include <cstdint>
#include <string>
#include <mutex>
#include <atomic>

#include <sys/types.h>
#include <sys/mman.h>
#include <immintrin.h>                   // include used to acces the intrinsics instructions

#include <fpga/QueuePair.h>

#define MAP_SIZE (32*1024UL)

/* ltoh: little to host */
/* htol: little to host */
#if __BYTE_ORDER == __LITTLE_ENDIAN
#  define ltohl(x)       (x)
#  define ltohs(x)       (x)
#  define htoll(x)       (x)
#  define htols(x)       (x)
#elif __BYTE_ORDER == __BIG_ENDIAN
#  define ltohl(x)     __bswap_32(x)
#  define ltohs(x)     __bswap_16(x)
#  define htoll(x)     __bswap_32(x)
#  define htols(x)     __bswap_16(x)
#endif

namespace fpga {

enum class qpState : uint8_t { RESET=0, INIT=1 , READY_RECV=2, READY_SEND=3, SQ_ERROR=4, ERROR=5 };
enum class appOpCode : uint8_t { APP_READ=0, APP_WRITE=1, APP_PART=2, APP_POINTER=3, APP_READ_CONSISTENT=4};
enum class direction : uint8_t { RX=0, TX=1 };
enum class PredicateOp : uint8_t {EQUAL=0, LESSTHAN=1, GREATERTHAN=2, NOTEQUAL=3};

enum class memoryOp : uint8_t { READ=0, WRITE=1 };

enum class userCtrlAddr : uint32_t { IPERF_BENCH = 0,
                                     IPERF_ADDR = 1,
                                     DDR_BENCH = 2,
                                     DMA_BENCH = 3,
                                     DEBUG = 4,
                                     //BOARDNUM = 7,
                                     //IPADDR = 8,
                                     //DMA_READS = 10,
                                     //DMA_WRITES = 11,
                                     ACCESS = 5,
                                     TUPLES_NO = 6,
                                     BASE_ADDR = 7,
                                     MEM_SIZE = 8,
                                     AGG_OP = 9,
                                     AGG_DONE = 10,
                                     IPERF_CYCLES = 12,
                                     DDR_BENCH_CYCLES = 13,
                                     DMA_BENCH_CYCLES = 14,
				     BASE_RESET_ADDR  = 15,
                                   };

enum class btreeCtrlAddr : uint32_t { ROOT = 0,
                                      QUERY = 1,
                                    };

static const uint32_t numDebugRegs = 0;
static const std::string RegNames[] = {"TLB Miss counter",
                                       "TLB Page Boundary crossing counter",
                                       };

enum class dmaCtrlAddr : uint32_t { TLB = 2,
                                 //DMA_BENCH = 3,
                                 //BOARDNUM = 7,
                                 //IPADDR = 8,
                                 DMA_READS = 10,
                                 DMA_WRITES = 11,
                                 //DEBUG = 12,
                                 STATS = 13,
                                 //DMA_BENCH_CYCLES = 14,
                              };
static const uint32_t numDmaStatsRegs = 10;
static const std::string DmaRegNames[] = {"DMA write cmd counter",
                                          "DMA write word counter",
                                          "DMA write pkg counter",
                                          "DMA write length counter",
                                          "DMA read cmd counter",
                                          "DMA read word counter",
                                          "DMA read pkg counter",
                                          "DMA read length counter",
                                          "TLB Miss counter",
                                          "TLB Page Boundary crossing counter",
                                          };
enum class ddrCtrlAddr: uint32_t { DEBUG = 9,
                                 STATS = 1,
                                 READS = 2,
                                 WRITES = 3
                              };
static const uint32_t numDdrStatsRegs = 13;
static const std::string DdrRegNames[] = {"write cmd counter",
                                          "write word counter",
                                          "write pkg counter",
                                          "write length counter",
                                          "write status counter",
                                          "write error counter",
                                          "read cmd counter",
                                          "read word counter",
                                          "read pkg counter",
                                          "read length counter",
                                          "read status counter",
                                          "read error counter",
                                          "datamover errors"
                                          };
enum class netCtrlAddr: uint32_t { CTX = 0,
                                 CONN = 1,
                                 POST = 3,
                                 BOARDNUM = 7,
                                 IPADDR = 8,
                                 ARP = 9,
                                 STATS = 12,
                                 CMD_OUT = 14,
                                 PC_META = 15,
                              };
static const uint32_t numNetStatsRegs = 25;
static const std::string NetRegNames[] = {"CRC drops",
                                          "PSN drops",
                                          "RX word count",
                                          "RX pkg count",
                                          "TX word count",
                                          "TX pkg count",
					  "ARP RX pkg count",
					  "ARP TX pkg",
					  "ARP request pkg",
					  "ARP reply pkg", //09
					  "ICMP RX pkg",
					  "ICMP TX pkg",
					  "TCP RX pkg",
					  "TCP TX pkg",
					  "res",
					  "res",
					  "ROCE RX pkg", //16
					  "ROCE TX pkg",
                                          "RoCE RX word count",
                                          "RoCE RX pkg count",
                                          "RoCE TX word count",
                                          "RoCE TX pkg count",
                                          "RoCE TX word count",
                                          "RoCE TX pkg count",
                                          "down"
                                          };

enum class mmCtrlAddr: uint32_t { TEST   = 0,
                                  TEST_2 = 1,                                 
                              };                                          
// one PCie BAR - AXIlite bar is split into 4 kB regions; each interface has one associated region
static const uint64_t userRegAddressOffset = 0;                                // role- user 4 kB  
static const uint64_t dmaRegAddressOffset = 4096;       
static const uint64_t ddrRegAddressOffset[] = { 8192, 12288, 16384, 20480 };   // 4 DDR memories can be connected to the FPGA
static const uint64_t netRegAddressOffset[] = {16384};                         // network stack region 

static const uint64_t mmRegAddressOffset = 0;                                  // bypass space

static const uint32_t cmdFifoDepth = 512;

union VAL{
   struct {
          uint8_t  op;
          uint32_t qpn;          
          uint64_t originAddr;
          uint64_t targetAddr;
          uint32_t size;  
   };
   __m256i x;
};   

class FpgaController
{
   public:
      FpgaController(int fd, int byfd);
      ~FpgaController();
      /*static fpgaManger& getInstance()
      {
         static fpgaManger instance;
         return instance;
      }*/
      void writeTlb(unsigned long vaddr, unsigned long paddr, bool isBase);
      uint64_t runDmaSeqWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength);
      uint64_t runDmaSeqReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength);
      uint64_t runDmaRandomWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength, uint32_t strideLength);
      uint64_t runDmaRandomReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength, uint32_t strideLength);

      uint64_t runDramSeqWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength, uint8_t channel);
      uint64_t runDramSeqReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength, uint8_t channel);
      uint64_t runDramRandomWriteBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength, uint32_t strideLength, uint8_t channel);
      uint64_t runDramRandomReadBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t numberOfAcceses, uint32_t chunkLength, uint32_t strideLength, uint8_t channel);

      uint64_t runIperfBenchmark(bool dualMode, uint16_t numConn, uint8_t wordCount, uint8_t packetGap, uint32_t timeINHectoSeconds, uint64_t timeInCycles);
      void setIperfAddress(uint8_t number, uint32_t address);

      //RoCE
      void writeContext(roce::QueuePair* par);
      void writeConnection(roce::QueuePair *par, int port);
      void postWrite(roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr);
      void postRead(roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr);
      
      //Network
      void setIpAddr(uint32_t addr);
      void setBoardNumber(uint8_t num);
      bool doArpLookup(uint32_t ipAddr, uint64_t& macAddr);

      void resetDmaReads();
      uint64_t getDmaReads();
      void resetDmaWrites();
      uint64_t getDmaWrites();
      void printDebugRegs();
      void printDmaStatsRegs();
      void printDdrStatsRegs(uint8_t channel);
      void printNetStatsRegs(uint8_t port=0);

     private:
      uint64_t runDmaBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t  numberOfAccesses, uint32_t chunkLength, uint32_t strideLength, memoryOp op);
      uint64_t runDramBenchmark(uint64_t baseAddr, uint64_t memorySize, uint32_t  numberOfAccesses, uint32_t chunkLength, uint32_t strideLength, memoryOp op, uint8_t channel);

      void writeReg(btreeCtrlAddr, uint32_t value);
      void writeReg(userCtrlAddr, uint32_t value);
      void writeReg(dmaCtrlAddr, uint32_t value);
      void writeReg(netCtrlAddr, uint32_t value, uint8_t port=0);
      //void writeReg(ctrlAddr addr, uint8_t value);
      //void writeReg(ctrlAddr addr, uint32_t value);

      // optwriteReg - uses ony AXI transaction
      void optwriteReg(userCtrlAddr, uint32_t value);
      void optwriteReg(dmaCtrlAddr, uint32_t value);
      void optwriteReg(netCtrlAddr, __m256i* value, uint8_t port=0);

      uint32_t readReg(userCtrlAddr addr);
      uint32_t readReg(dmaCtrlAddr addr);
      uint32_t readReg(ddrCtrlAddr addr, uint8_t channel);
      uint32_t readReg(netCtrlAddr addr, uint8_t port=8);

      void writeMM(mmCtrlAddr, uint64_t value);
      uint64_t readMM(mmCtrlAddr addr);

      void postCmd(appOpCode op, roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr);
      void optpostCmd(appOpCode op, roce::QueuePair* pair, const void* originAddr, uint32_t size, const void* targetAddr);

   public:
      FpgaController(FpgaController const&)     = delete;
      void operator =(FpgaController const&) = delete;
   private:
   void*  m_base;
   void*  by_base;

   static std::atomic_uint cmdCounter;  //std::atomic<unsigned int>
   //static uint32_t cmdCounter;
   static std::mutex  ctrl_mutex;
   static std::mutex  btree_mutex;

   static uint64_t mmTestValue;
};

} /* namespace fpga */

#endif
