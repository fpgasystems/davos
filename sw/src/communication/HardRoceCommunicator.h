/*
 * HardRoceCommunicator.h
 *
 *  Created on: Nov 13, 2017
 *      Author: dasidler
 */

#ifndef SRC_HASHJOIN_COMMUNICATION_HARDROCECOMMUNICATOR_H_
#define SRC_HASHJOIN_COMMUNICATION_HARDROCECOMMUNICATOR_H_

#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <atomic>

#include <communication/Communicator.h>
#include <fpga/Configuration.h>
//#include <core/HashJoinThread.h>
//#include <communication/HardRoceWindow.h>
#include <fpga/FpgaController.h>
#include <fpga/QueuePair.h>

//namespace hashjoin {

namespace fpga {
   class FpgaController;
}

namespace communication {

struct RoceWinMeta {
   void*    base;
   uint64_t size;
};

struct RoceWin {
   RoceWinMeta windows[fpga::Configuration::MAX_NODES];
};
//class HardRoceWindow;

/*struct measurementMsg {
   performance::Measurements data;
   uint64_t thread;
};*/

class HardRoceCommunicator : public Communicator {

public:

	HardRoceCommunicator(fpga::FpgaController* fpga, uint32_t nodeId, uint32_t numberOfNodes, uint32_t numberOfThreads, const char* ipAddress);
	virtual ~HardRoceCommunicator();

public:

	void connect();
	void prepare();
   /*void barrier(core::HashJoinThread* thread);
   void collectMeasurements(core::HashJoinThread* thread);*/

public:

	/*void reduceAll(uint64_t *input, uint64_t *output, uint32_t numberOfElements, core::HashJoinThread* thread);
   void reduceAllThread(uint64_t *input, uint64_t *output, uint32_t numberOfElements, core::HashJoinThread* thread);
	void prefixSum(uint64_t *input, uint64_t *output, uint32_t numberOfElements, core::HashJoinThread* thread);
   void prefixSumThread(uint64_t *input, uint64_t *output, uint32_t numberOfElements, core::HashJoinThread* thread);*/

   void put(const void* originAddr, uint64_t originLength, uint64_t originOffset, int targetProcess, uint64_t targetOffset, communication::RoceWin *win);
   void get(const void* originAddr, uint64_t originLength, uint64_t originOffset, int targetProcess, uint64_t targetOffset, communication::RoceWin *win);

   void flushLocal();
   void checkWrites(uint64_t expected);

protected:

   void initializeLocalQueues();
   int masterExchangeQueues();
   int clientExchangeQueues();

   int masterAllreduceSum64(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int masterAllreduceSum64Thread(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int slaveAllreduceSum64(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int slaveAllreduceSum64Thread(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int masterScanSum64(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int masterScanSum64Inter(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int masterScanSum64Thread(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int slaveScanSum64(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count);
   int masterExchangeWindow(RoceWin* win);
   int slaveExchangeWindow(RoceWin* win);

	//Window * createWindow(uint64_t size, bool isOuter=false);
public:
   void exchangeWindow(void* base, uint64_t size, RoceWin* win);

protected:
   fpga::FpgaController* fpga;
	const char* masterIpAddress;
   int*  connections;
   uint16_t port;
   uint16_t ibPort;
   roce::QueuePair*   pairs;
   std::atomic<uint64_t> pushedLength;
   uint64_t totalExpected;
   uint64_t totalTuplesExpected;
	//uint16_t *portNumbers;

   static uint64_t*   reducedInput;
   static uint64_t*   reducedOutput;

   //static performance::Measurements** measurements;
   //static measurementMsg* messages;

};

} /* namespace communication */
//} /* namespace hashjoin */

#endif /* SRC_HASHJOIN_COMMUNICATION_HARDROCECOMMUNICATOR_H_ */
