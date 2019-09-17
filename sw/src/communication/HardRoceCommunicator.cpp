/*
 * HardRoceCommunicator.cpp
 *
 *  Created on: Nov 13, 2017
 *      Author: dasidler
 */

#include "HardRoceCommunicator.h"

#include <iostream>
#include <sstream>
#include <fstream>
#include <iomanip>
#include <cstring>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <random>
#include <chrono>
#include <thread>
#include <limits>
#include <assert.h>

//#include <hashjoin/core/Configuration.h>
//#include <hashjoin/utils/Debug.h>

//#include <communication/HardRoceWindow.h>

//namespace hashjoin {
namespace communication {

std::mutex reduction_mutex;
uint64_t* HardRoceCommunicator::reducedInput = nullptr;
uint64_t* HardRoceCommunicator::reducedOutput = nullptr;
//performance::Measurements** HardRoceCommunicator::measurements = nullptr;
//measurementMsg* HardRoceCommunicator::messages = nullptr;

//TODO maybe pass FPGA object instead
HardRoceCommunicator::HardRoceCommunicator(fpga::FpgaController* fpga, uint32_t nodeId, uint32_t numberOfNodes, uint32_t numberOfThreads, const char* masterIpAddress) {
   
   port = 18515;
   ibPort = 0;
   this->fpga = fpga;
	this->nodeId = nodeId;
	this->numberOfNodes = numberOfNodes;
	this->numberOfThreads = numberOfThreads;
	this->masterIpAddress = masterIpAddress;

   this->connections = new int[numberOfNodes];
   this->pairs = new roce::QueuePair[numberOfNodes];
   this->pushedLength = 0;
   this->totalExpected = 0;
   this->totalTuplesExpected = 0;

   //TODO move some of this stuff

   //Initialize local queues
   //HJ_DEBUG("HardRoce", "Setting local queues");
   initializeLocalQueues();
   //HJ_DEBUG("HardRoce", "HardRoce ready to connect");

   uint32_t baseIpAddr = fpga::Configuration::BASE_IP_ADDR;
   fpga->setIpAddr(baseIpAddr + nodeId);
   fpga->setBoardNumber(nodeId);
   fpga->resetDmaReads();
   fpga->resetDmaWrites();
   //fpga->resetPartitionTuples();
   
   int ret = 1;
   if (nodeId == 0) {
      ret = masterExchangeQueues();
   } else {
      std::this_thread::sleep_for(std::chrono::seconds(1));
      ret = clientExchangeQueues();
   }
   if (ret) {
      std::cerr << "Exchange failed";
      //return 1;
   }
   std::cout << "exchange done." << std::endl;

   //load context & connections to FPGA
   for (int i = 0; i < numberOfNodes; i++) {
      if (i == nodeId) {
         continue;
      }
      fpga->writeContext(&(pairs[i]));
      fpga->writeConnection(&(pairs[i]), port);
   }

   for (int i = 0; i < numberOfNodes; i++) {
      if (i == nodeId) {
         continue;
      }
      uint64_t macAddr = 0;
      fpga->doArpLookup(baseIpAddr+i, macAddr);
   }
}

HardRoceCommunicator::~HardRoceCommunicator() {

   for (int i = 0; i < numberOfNodes; i++) {
      if (i == nodeId) {
         continue;
      }
      close(connections[i]);
   }

   delete[] connections;
   delete[] pairs;
}

void HardRoceCommunicator::connect() {
	
   //Already done above in
	/*for (uint32_t i = 0; i < nodeId; ++i) {
		infinity::queues::QueuePair *qp = qpFactory->acceptIncomingConnection(&nodeId, sizeof(uint32_t));
		uint32_t *remoteNodeId = (uint32_t *) qp->getUserData();
		this->connections[*remoteNodeId] = qp;
	}

	this->connections[nodeId] = qpFactory->createLoopback(&nodeId, sizeof(uint32_t));

	for (uint32_t i = nodeId + 1; i < numberOfNodes; ++i) {
		infinity::queues::QueuePair *qp = qpFactory->connectToRemoteHost(ipAddresses[i].c_str(), portNumbers[i], &nodeId, sizeof(uint32_t));
		uint32_t *remoteNodeId = (uint32_t *) qp->getUserData();
		this->connections[*remoteNodeId] = qp;
	}*/
   
}

void HardRoceCommunicator::prepare() {

	//Already done
	/*bool isCoordinator = (nodeId == 0);
	uint32_t bufferSize = sizeof(infiniband_buffer_t);
	uint32_t globalNumberOfThreads = numberOfNodes * numberOfThreads;

	uint32_t bufferCount = (isCoordinator) ? (globalNumberOfThreads + numberOfThreads) : (numberOfThreads);

	receiveMemory = new infinity::memory::RegisteredMemory(this->context, bufferSize * bufferCount);
	receiveBuffers = new infinity::memory::Buffer *[bufferCount];

	sendMemory = new infinity::memory::RegisteredMemory(this->context, bufferSize * bufferCount);
	sendBuffers = new infinity::memory::Buffer *[bufferCount];

	for (uint32_t i = 0; i < bufferCount; ++i) {
		receiveBuffers[i] = new infinity::memory::Buffer(context, receiveMemory, i * bufferSize, bufferSize);
		sendBuffers[i] = new infinity::memory::Buffer(context, sendMemory, i * bufferSize, bufferSize);
		this->context->postReceiveBuffer(receiveBuffers[i]);
	}*/

}

/*void HardRoceCommunicator::barrier(core::HashJoinThread* thread) {

   thread->barrier();
   //Network barrier over TCP
   int n = 0;
   uint64_t msg = 0xF0F0F0F0;
   uint64_t recvMsg = 0;
   if (thread->info.localThreadId == 0) {
      if (thread->info.globalThreadId == 0) {
         //receive ping messages
         for (int i = 1; i < numberOfNodes; ++i) {
            if ((n = ::read(connections[i], &recvMsg, sizeof(recvMsg))) != sizeof(msg)) {
               std::cerr << "Could not read ping fomr node: " << i << ", receivd: " << n << "bytes." << std::endl;
            }
         }
         //send ping messages
         for (int i = 1; i < numberOfNodes; ++i) {
            if ((n = ::write(connections[i], &msg, sizeof(msg))) != sizeof(msg)) {
               std::cerr << "Could not ping node: " << i << std::endl;
            }
         }
      } else {
         //send ping message
         if ((n = ::write(connections[0], &msg, sizeof(msg))) != sizeof(msg)) {
            std::cerr << "Could not ping master." << std::endl;
            close(connections[0]);
         }
         //receive ping message
         if ((n = ::read(connections[0], &recvMsg, sizeof(recvMsg))) != sizeof(msg)) {
            std::cerr << "Could not read complete ping from master: " << n << std::endl;
            close(connections[0]);
         }
      }
   }
   thread->barrier();

}

void HardRoceCommunicator::collectMeasurements(core::HashJoinThread* thread) {

   uint32_t globalNumberOfThreads = numberOfNodes * numberOfThreads;

   if (thread->info.localThreadId == 0) {
      messages = new measurementMsg[numberOfThreads];
      measurements = new performance::Measurements *[globalNumberOfThreads];
   }

   thread->barrier();
   if (thread->info.nodeId != 0) {
      messages[thread->info.localThreadId].thread = thread->info.globalThreadId;
      messages[thread->info.localThreadId].data = thread->measurements;
   } else {
      measurements[thread->info.localThreadId] = &(thread->measurements);
   }
   thread->barrier();

   if (thread->info.globalThreadId == 0) {

      HJ_DEBUG_THREAD(thread->info.localThreadId, "Collect", "Thread is coordinator of collect");

      measurementMsg* bufferedMeasurements = new measurementMsg [globalNumberOfThreads-numberOfThreads];

      for (uint32_t j = 1; j < numberOfNodes; ++j) {
         for (uint32_t i = 0; i < numberOfThreads; ++i) {
            //receive measurements
            int recvCount = 0;
            int n = 0;
            measurementMsg* msg = &(bufferedMeasurements[(j-1)*numberOfThreads+i]);
            char* recvPtr = (char*) msg;
            do {
               n = ::read(connections[j], recvPtr, sizeof(measurementMsg) - recvCount);
               if (n < 0) {
                  std::cerr << "Could not read measurement from node: " << j << ", received " << n << "bytes." << std::endl;
                  ::close(connections[j]);
               }
               recvPtr += n;
               recvCount += n;
            } while(recvCount < sizeof(measurementMsg));

            uint64_t incomingNodeId = msg->thread;
            measurements[incomingNodeId] = &(msg->data);
         }
      }

      performance::Measurements::PROCESS(measurements, globalNumberOfThreads, numberOfNodes);

      delete[] bufferedMeasurements;

   } else if (thread->info.localThreadId == 0) {

      HJ_DEBUG_THREAD(thread->info.localThreadId, "Collect", "Thread is participating in collect");

      for (uint32_t i = 0; i < numberOfThreads; ++i) {
         int n = 0;
         if ((n = ::write(connections[0], &(messages[i]), sizeof(measurementMsg))) != sizeof(measurementMsg)) {
            std::cerr << "Could not send measurement to master" << std::endl;
            ::close(connections[0]);
         }
      }
   }

   if (thread->info.localThreadId == 0) {
      delete[] measurements;
      delete[] messages;
   }
}

void HardRoceCommunicator::reduceAll(uint64_t* input, uint64_t* output, uint32_t numberOfElements, core::HashJoinThread* thread) {

   if (thread->info.localThreadId == 0) {
      reducedInput = new uint64_t[numberOfElements];
      reducedOutput = new uint64_t[numberOfElements];
      memset(reducedInput, 0, numberOfElements*sizeof(uint64_t));
   }
   thread->barrier();

   //reduce by each thread
   {
      std::lock_guard<std::mutex> guard(reduction_mutex);
      for (uint32_t i = 0; i < numberOfElements; ++i) {
         reducedInput[i] += input[i];
      }
   }

   thread->barrier();

	if (thread->info.globalThreadId == 0) {

		HJ_DEBUG_THREAD(thread->info.localThreadId, "Reduce", "Thread is coordinator of reduce");

		masterAllreduceSum64(reducedInput, reducedOutput, numberOfElements);

	} else if (thread->info.localThreadId == 0) {

      HJ_DEBUG_THREAD(thread->info.localThreadId, "Reduce", "Thread is participating in reduce");

		slaveAllreduceSum64(reducedInput, reducedOutput, numberOfElements);

	}

	HJ_DEBUG_THREAD(thread->info.localThreadId, "Reduce", "Thread is waiting at operation barrier for reduce");
	thread->barrier();
   
   for (uint32_t i = 0; i < numberOfElements; ++i) {
      output[i] = reducedOutput[i];
   }

   thread->barrier();
   if (thread->info.localThreadId == 0) {
      delete[] reducedInput;
      delete[] reducedOutput;
   }

}

void HardRoceCommunicator::reduceAllThread(uint64_t* input, uint64_t* output, uint32_t numberOfElements, core::HashJoinThread* thread) {

   if (thread->info.localThreadId == 0) {
      reducedInput = new uint64_t[numberOfElements*numberOfThreads];
      reducedOutput = new uint64_t[numberOfElements*numberOfThreads];
      memset(reducedInput, 0, numberOfElements*numberOfThreads*sizeof(uint64_t));
   }
   thread->barrier();

   //reduce by each thread
   uint32_t offset = thread->info.localThreadId * numberOfElements;
   {
      //std::lock_guard<std::mutex> guard(reduction_mutex);//TODO remove
      for (uint32_t i = 0; i < numberOfElements; ++i) {
         reducedInput[offset+i] = input[i];
      }
   }

   thread->barrier();

	if (thread->info.globalThreadId == 0) {

		HJ_DEBUG_THREAD(thread->info.localThreadId, "Reduce", "Thread is coordinator of reduce");

		masterAllreduceSum64Thread(reducedInput, reducedOutput, numberOfElements);

	} else if (thread->info.localThreadId == 0) {

      HJ_DEBUG_THREAD(thread->info.localThreadId, "Reduce", "Thread is participating in reduce");

		slaveAllreduceSum64Thread(reducedInput, reducedOutput, numberOfElements);

	}

	HJ_DEBUG_THREAD(thread->info.localThreadId, "Reduce", "Thread is waiting at operation barrier for reduce");
	thread->barrier();
   
   for (uint32_t i = 0; i < numberOfElements; ++i) {
      output[i] = reducedOutput[offset+i];
   }

   thread->barrier();
   if (thread->info.localThreadId == 0) {
      delete[] reducedInput;
      delete[] reducedOutput;
   }

}


void HardRoceCommunicator::prefixSum(uint64_t* input, uint64_t* output, uint32_t numberOfElements, core::HashJoinThread* thread) {


   if (thread->info.localThreadId == 0) {
      reducedInput = new uint64_t[numberOfElements*numberOfThreads];
      reducedOutput = new uint64_t[numberOfElements*numberOfThreads];
   }
   thread->barrier();

   //reduce by each thread
   uint32_t offset = thread->info.localThreadId * numberOfElements;
   {
      //TODO mutex not necesary
      //std::lock_guard<std::mutex> guard(reduction_mutex);
      for (uint32_t i = 0; i < numberOfElements; ++i) {
         reducedInput[offset+i] = input[i];
      }
   }

   thread->barrier();

	if (thread->info.globalThreadId == 0) {

		HJ_DEBUG_THREAD(thread->info.localThreadId, "PrefixSum", "Thread is coordinator of prefix sum");

		masterScanSum64Inter(reducedInput, reducedOutput, numberOfElements);

	} else if (thread->info.localThreadId == 0) {
      
      HJ_DEBUG_THREAD(thread->info.localThreadId, "PrefixSum", "Thread is participating in prefix sum");

		slaveScanSum64(reducedInput, reducedOutput, numberOfElements);

	}
   
   
   HJ_DEBUG_THREAD(thread->info.localThreadId, "PrefixSum", "Thread is waiting at operation barrier for prefix sum");
	thread->barrier();

   for (uint32_t i = 0; i < numberOfElements; ++i) {
      output[i] = reducedOutput[offset+i];
      output[i] -= input[i];
   }

   thread->barrier();
   if (thread->info.localThreadId == 0) {
      delete[] reducedInput;
      delete[] reducedOutput;
   }
	
}

void HardRoceCommunicator::prefixSumThread(uint64_t* input, uint64_t* output, uint32_t numberOfElements, core::HashJoinThread* thread) {


   if (thread->info.localThreadId == 0) {
      reducedInput = new uint64_t[numberOfElements*numberOfThreads];
      reducedOutput = new uint64_t[numberOfElements*numberOfThreads];
   }
   thread->barrier();

   //reduce by each thread
   uint32_t offset = thread->info.localThreadId * numberOfElements;
   {
      //TODO mutex not necesary
      std::lock_guard<std::mutex> guard(reduction_mutex);
      for (uint32_t i = 0; i < numberOfElements; ++i) {
         reducedInput[offset+i] = input[i];
      }
   }

   thread->barrier();

	if (thread->info.globalThreadId == 0) {

		HJ_DEBUG_THREAD(thread->info.localThreadId, "PrefixSum", "Thread is coordinator of prefix sum");

		masterScanSum64Thread(reducedInput, reducedOutput, numberOfElements);

	} else if (thread->info.localThreadId == 0) {
      
      HJ_DEBUG_THREAD(thread->info.localThreadId, "PrefixSum", "Thread is participating in prefix sum");

		slaveScanSum64(reducedInput, reducedOutput, numberOfElements);

	}
   
   
   HJ_DEBUG_THREAD(thread->info.localThreadId, "PrefixSum", "Thread is waiting at operation barrier for prefix sum");
	thread->barrier();

   for (uint32_t i = 0; i < numberOfElements; ++i) {
      output[i] = reducedOutput[offset+i];
      //output[i] -= input[i];
   }

   thread->barrier();
   if (thread->info.localThreadId == 0) {
      delete[] reducedInput;
      delete[] reducedOutput;
   }
}*/

/*Window* HardRoceCommunicator::createWindow(uint64_t size, bool isOuter) {

   //Allocate memory
   void* base = (data::CompressedTuple*) fpga::Fpga::allocate(size); //localWindowSize *     sizeof(data::CompressedTuple));
   communication::RoceWin* win = (communication::RoceWin*) calloc(1, sizeof(communication::RoceWin));

   win->windows[nodeId].base = base;
   win->windows[nodeId].size = size;
   //Exchange windows
   if (this->nodeId == 0) {
       masterExchangeWindow(win);
   } else {
       slaveExchangeWindow(win);
   }

   //TODO hand over fpgaController??
   return new communication::HardRoceWindow(numberOfNodes, numberOfThreads, this, win, base, size, isOuter);
	
}*/

void HardRoceCommunicator::exchangeWindow(void* base, uint64_t size, RoceWin* win) {

   win->windows[nodeId].base = base;
   win->windows[nodeId].size = size;
   //Exchange windows
   if (this->nodeId == 0) {
       masterExchangeWindow(win);
   } else {
       slaveExchangeWindow(win);
   }

}

void HardRoceCommunicator::put(const void* originAddr, uint64_t originLength, uint64_t originOffset, int targetProcess, uint64_t targetOffset, RoceWin* win) {
   void* localAddr = (void*) (((char*) originAddr) + originOffset);
   void* remotAddr = (void*) (((char*) win->windows[targetProcess].base) + targetOffset);
   //Check if local Put
   if (targetProcess == nodeId) {
      memcpy(remotAddr, localAddr, originLength);
   } else {
      pushedLength += originLength;
      while (originLength > std::numeric_limits<uint32_t>::max()) {
         fpga->postWrite(&(pairs[targetProcess]), localAddr, std::numeric_limits<uint32_t>::max(), remotAddr);
         localAddr = (void*) (((char*) localAddr) + std::numeric_limits<uint32_t>::max());
         originLength -= std::numeric_limits<uint32_t>::max();
      }
      fpga->postWrite(&(pairs[targetProcess]), localAddr, (uint32_t) originLength, remotAddr);
   }
}

void HardRoceCommunicator::get(const void* originAddr, uint64_t originLength, uint64_t originOffset, int targetProcess, uint64_t targetOffset, RoceWin* win) {
   void* localAddr = (void*) (((char*) originAddr) + originOffset);
   void* remotAddr = (void*) (((char*) win->windows[targetProcess].base) + targetOffset);
   //Check if local Get
   if (targetProcess == nodeId) {
      memcpy(localAddr, remotAddr, originLength);
   } else {
      while (originLength > std::numeric_limits<uint32_t>::max()) {
         fpga->postRead(&(pairs[targetProcess]), localAddr, std::numeric_limits<uint32_t>::max(), remotAddr);
         localAddr = (void*) (((char*) localAddr) + std::numeric_limits<uint32_t>::max());
         originLength -= std::numeric_limits<uint32_t>::max();
      }
      fpga->postRead(&(pairs[targetProcess]), localAddr, (uint32_t) originLength, remotAddr);
   }
}

void HardRoceCommunicator::flushLocal() {
   uint64_t flushed = fpga->getDmaReads();
   while(flushed != pushedLength) {
#ifdef JOIN_DEBUG_PRINT
      printf("flushed: %lu, expected: %lu\n", flushed, pushedLength.load());
      fpga->printDebugRegs();
      fpga->printDmaDebugRegs();
      std::this_thread::sleep_for(std::chrono::seconds(2));
#endif
      std::this_thread::sleep_for(std::chrono::microseconds(1));
      flushed = fpga->getDmaReads();
   }
}


//Not thread safe
void HardRoceCommunicator::checkWrites(uint64_t expected) {

   uint64_t received = fpga->getDmaWrites();
   totalExpected += expected;
   while (received < totalExpected) {
#ifdef JOIN_DEBUG_PRINT
      printf("received: %lu, expected: %lu, totalExpected: %lu\n", received, expected, totalExpected);
      fpga->printDebugRegs();
      fpga->printDmaDebugRegs();
      std::this_thread::sleep_for(std::chrono::seconds(2));
#endif
      std::this_thread::sleep_for(std::chrono::microseconds(1));
      received = fpga->getDmaWrites();
   }
}

static unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();


void HardRoceCommunicator::initializeLocalQueues() {
   std::default_random_engine rand_gen(seed);
   std::uniform_int_distribution<int> distr(0, std::numeric_limits<std::uint32_t>::max());

   //Assume IPv4
   uint32_t ipAddr = fpga::Configuration::BASE_IP_ADDR;
   ipAddr += nodeId;

   for (int i = 0; i < numberOfNodes; ++i) {
      pairs[i].local.uintToGid(0, ipAddr);
      pairs[i].local.uintToGid(8, ipAddr);
      pairs[i].local.uintToGid(16, ipAddr);
      pairs[i].local.uintToGid(24, ipAddr);
      pairs[i].local.qpn = 0x3 + i;
      pairs[i].local.psn = distr(rand_gen);
      pairs[i].local.rkey = 0;
      pairs[i].local.vaddr = 0; //TODO remove
   }

   /*for (int i = 0; i < numberOfNodes; i++) {
      char gid[] = "FE80000000000000020A35FFFF029DE5";
      if (core::Configuration::IP_VERSION == 4) {
         memcpy(gid, "0B01D4D10B01D4D10B01D4D10B01D4D1", 32);
         //gid[] = "0B01D4D10B01D4D10B01D4D10B01D4D1";
      }
#ifdef IB_DEBUG
      printf("my gid: %s\n", pairs[i].local.gid);
#endif

      //Add board number
      char digit = gid[31];
      int numdigit = ((int)(digit - '0')) + nodeId;
      char newdigit = numdigit + '0';
      gid[31] = newdigit;
      strncpy(pairs[i].local.gid, gid, sizeof(gid));

      //TODO manage them somehow
      pairs[i].local.qpn = 0x11 + i;
      pairs[i].local.psn = distr(rand_gen);
      pairs[i].local.rkey = 0;
   } //for*/
}


int HardRoceCommunicator::masterExchangeQueues() {
   char *service;
   char recv_buf[100];
   int n;
   int sockfd = -1, connfd;
   struct sockaddr_in server;
   memset(recv_buf, 0, 100);

   std::cout << "server exchange" << std::endl;

   /*if (asprintf(&service, "%d", data->port) < 0)
      return 1;*/
   sockfd = ::socket(AF_INET, SOCK_STREAM, 0);
   if (sockfd == -1) {
      std::cerr << "Could not create socket" << std::endl;
      return 1;
   }

   //n = getaddrinfo(NULL, service, &hints, 
   //Prepare the sockaddr_in structure
   server.sin_family = AF_INET;
   server.sin_addr.s_addr = INADDR_ANY;
   server.sin_port = htons( port);

   if (::bind(sockfd, (struct sockaddr*)&server, sizeof(server)) < 0) {
      std::cerr << "Could not bind socket" << std::endl;
      return 1;
   }


   if (sockfd < 0 ) {
      std::cerr << "Could not listen to port " << port << std::endl;
      return 1;
   }

   roce::IbQueue* allQueues = new roce::IbQueue[numberOfNodes*numberOfNodes];

   listen(sockfd, numberOfNodes);
   int i = 1;
   while (i < numberOfNodes) {
      //std::cout << "count: " << count << std::endl;
      connfd = ::accept(sockfd, NULL, 0);
      if (connfd < 0) {
         std::cerr << "Accep() failed" << std::endl;
         return 1;
      }

      //generate local string, this is just for getting the length...
      std::string msgString = pairs[0].local.encode();
      size_t msgLen = msgString.length();

      for (int j = 0; j < numberOfNodes; j++) {
         if (j == i) {
            continue;
         }
         //read msg
         n = ::read(connfd, recv_buf, msgLen);
         if (n != msgLen) {
            std::cerr << "Could not read remote address" << std::endl;
            close(connfd);
            return 1;
         }

         //parse remote connection
         allQueues[i*numberOfNodes+j].decode(recv_buf, msgLen);
         allQueues[i*numberOfNodes+j].print("remote: ");
         //Check if it is for master
         if (j == 0) {
            pairs[i].remote.decode(recv_buf, msgLen);
         }
      }//for
      connections[i] = connfd;
      i++;
   }//while

   //send queues
   i = 1;
   while(i < numberOfNodes) {


      for (int j = 0; j < numberOfNodes; j++) {
         if (i == j) {
            continue;
         }
         std::string msgString;
         if (j == 0) {
            msgString = pairs[i].local.encode();
         } else {
            msgString = allQueues[j*fpga::Configuration::MAX_NODES+i].encode();
         }
         size_t msgLen = msgString.length();

         //write msg
         if (::write(connections[i], msgString.c_str(), msgLen) != msgLen)  {
            std::cerr << "Could not send local address" << std::endl;
            ::close(connections[i]);
            return 1;
         }
      }//for
      i++;
   }//while

   ::close(sockfd);
   delete[] allQueues;
   return 0;
}

int HardRoceCommunicator::clientExchangeQueues() {
   struct addrinfo *res, *t;
   struct addrinfo hints = {};
   hints.ai_family = AF_INET;
   hints.ai_socktype = SOCK_STREAM;

   char* service;
   char recv_buf[100];
   int n = 0;
   int sockfd = -1;
   memset(recv_buf, 0, 100);

   std::cout << "client exchange" << std::endl;

   if (asprintf(&service, "%d", port) < 0) {
      std::cerr << "service failed" << std::endl;
      return 1;
   }

   n = getaddrinfo(masterIpAddress, service, &hints, &res);
   if (n < 0) {
      std::cerr << "[ERROR] getaddrinfo";
      free(service);
      return 1;
   }

   for (t = res; t; t = t->ai_next) {
      sockfd = ::socket(t->ai_family, t->ai_socktype, t->ai_protocol);
      if (sockfd >= 0) {
         if (!::connect(sockfd, t->ai_addr, t->ai_addrlen)) {
            break;
         }
         ::close(sockfd);
         sockfd = -1;
      }
   }

   if (sockfd < 0) {
      std::cerr << "Could not connect to master: " << masterIpAddress << ":" << port << std::endl;
      return 1;
   }

   for (int i = 0; i < numberOfNodes; i++) {
      if (i == nodeId) {
         continue;
      }
      std::cout << "build msg" << std::endl;
      std::string msgString = pairs[i].local.encode();
      std::cout << "local : " << msgString << std::endl;

      size_t msgLen = msgString.length();
      if (write(sockfd, msgString.c_str(), msgLen) != msgLen) {
         std::cerr << "could not send local address" << std::endl;
         close(sockfd);
         return 1;
      }

      if ((n = ::read(sockfd, recv_buf, msgLen)) != msgLen) {
         std::cout << "n: " << n << ", instread of " << msgLen << std::endl; 
         std::cout << "received msg: " << recv_buf << std::endl;
         std::cerr << "Could not read remote address" << std::endl;
         ::close(sockfd);
         return 1;
      }

      pairs[i].remote.decode(recv_buf, msgLen);
      pairs[i].remote.print("remote");
   }//for

   //keep connection around
   connections[0] = sockfd;

   if (res) 
      freeaddrinfo(res);
   free(service);

   return 0;
}

int HardRoceCommunicator::masterAllreduceSum64(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* tempbuf = new char[sizeof(uint64_t)*count];
   char* basetempbuf = tempbuf;
   uint64_t* acc = (uint64_t*) recvbuf;  
  //init recvbuf
   for (int j = 0; j < count; j++) {
      acc[j] = ((uint64_t*) sendbuf)[j];
   }

   uint32_t i = 1;
   while (i < numberOfNodes) {
      int connfd = connections[i];
      do {
         n = ::read(connfd, tempbuf, (sizeof(uint64_t)*count) - recvCount);
         if (n < 0) {
            std::cerr << "Could not read: " << n << std::endl;
            ::close(connfd);
            return 1;
         }
         recvCount += n;
         tempbuf += n;
      } while (recvCount < sizeof(uint64_t)*count);

      //accumulate
      for (int j = 0; j < count; j++) {
         acc[j] += ((uint64_t*) basetempbuf)[j];
      }
      i++;
   }//while

   //send accumulated values
   i = 1;
   while(i < numberOfNodes) {
      //write msg
      if ((n = ::write(connections[i], acc, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
         std::cerr << "Could not send" << std::endl;
         ::close(connections[i]);
         return 1;
      }
      i++;
   }//while

   delete[] basetempbuf;
   return 0;
}

int HardRoceCommunicator::masterAllreduceSum64Thread(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* tempbuf = new char[sizeof(uint64_t)*count];
   char* basetempbuf = tempbuf;
   uint64_t* acc; 

   for (int t = 0; t < numberOfThreads; ++t) {

      acc = recvbuf + (count*t);
      for (int j = 0; j < count; j++) {
         acc[j] = ((uint64_t*) sendbuf)[t*count+j];
      }
      uint32_t i = 1;
      while (i < numberOfNodes) {
         int connfd = connections[i];
         recvCount = 0;
         tempbuf = basetempbuf;
         do {
            n = ::read(connfd, tempbuf, (sizeof(uint64_t)*count) - recvCount);
            if (n < 0) {
               std::cerr << "Could not read: " << n << std::endl;
               ::close(connfd);
               return 1;
            }
            recvCount += n;
            tempbuf += n;
         } while (recvCount < sizeof(uint64_t)*count);

         //accumulate
         for (int j = 0; j < count; j++) {
            acc[j] += ((uint64_t*) basetempbuf)[j];
         }
         i++;
      }//while

      //send accumulated values
      i = 1;
      while(i < numberOfNodes) {

         //write msg
         if ((n = ::write(connections[i], acc, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
            std::cerr << "Could not send" << std::endl;
            ::close(connections[i]);
            return 1;
         }
         i++;
      }//while
   }//for

   delete[] basetempbuf;
   return 0;
}

int HardRoceCommunicator::slaveAllreduceSum64(const uint64_t* sendbuf, uint64_t* output, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* recvbuf = (char*) output;

   //write msg
   if ((n = ::write(connections[0], sendbuf, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
      std::cerr << "Could not send" << std::endl;
      close(connections[0]);
      return 1;
   }

   do {
      n = ::read(connections[0], recvbuf, (sizeof(uint64_t)*count) - recvCount);
      if (n < 0) {
         std::cerr << "Could not read: " << n << std::endl;
         ::close(connections[0]);
         return 1;
      }
      recvCount += n;
      recvbuf = ((char*) recvbuf) + n;
   } while (recvCount < sizeof(uint64_t)*count);

   return 0;
}

int HardRoceCommunicator::slaveAllreduceSum64Thread(const uint64_t* sendbuf, uint64_t* output, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* recvbuf = (char*) output;

   for (int t = 0; t < numberOfThreads; ++t) {
      recvCount = 0;
      //write msg
      if ((n = ::write(connections[0], sendbuf, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
         std::cerr << "Could not send" << std::endl;
         close(connections[0]);
         return 1;
      }
      sendbuf += count;

      do {
         n = ::read(connections[0], recvbuf, (sizeof(uint64_t)*count) - recvCount);
         if (n < 0) {
            std::cerr << "Could not read: " << n << std::endl;
            ::close(connections[0]);
            return 1;
         }
         recvCount += n;
         recvbuf = ((char*) recvbuf) + n;
      } while (recvCount < sizeof(uint64_t)*count);
   }//for

   return 0;
}

int HardRoceCommunicator::masterScanSum64(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* tempbuf = new char[count*sizeof(uint64_t)];
   char* basetempbuf = tempbuf;
   uint64_t* acc = (uint64_t*) recvbuf;
   //init recvbuf
   for (int j = 0; j < count; j++) {
      acc[j] = ((uint64_t*) sendbuf)[(numberOfThreads-1)*count+j];
   }

   uint32_t i = 1;
   while (i < numberOfNodes) {
      int connfd = connections[i];

      for (uint32_t t = 0; t < numberOfThreads; t++) {
         recvCount = 0;
         tempbuf = basetempbuf;

         do {
            n = ::read(connfd, tempbuf, (sizeof(uint64_t)*count) - recvCount);
            if (n < 0) {
               std::cerr << "Could not read: " << n << std::endl;
               ::close(connfd);
               return 1;
            }
            recvCount += n;
            tempbuf +=n;
         } while(recvCount < sizeof(uint64_t)*count);

         //accumulate
         for (int j = 0; j < count; j++) {
            acc[j] += ((uint64_t*) basetempbuf)[j];
         }

         //Send to node i
         //write msg
         if ((n = ::write(connfd, acc, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
            std::cerr << "Could not send" << std::endl;
            ::close(connfd);
            return 1;
         }
      }
      i++;
   }//while

   memcpy(recvbuf, sendbuf, sizeof(uint64_t)*count*numberOfThreads);

   delete[] basetempbuf;
   return 0;
}

int HardRoceCommunicator::masterScanSum64Inter(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* tempbuf = new char[count*sizeof(uint64_t)];
   char* basetempbuf = tempbuf;
   uint64_t* acc = new uint64_t[count];
   memset(acc, 0, count*sizeof(uint64_t));

   for (uint32_t t = 0; t < numberOfThreads; t++) {
      //accumulate local
      for (int j = 0; j < count; j++) {
         acc[j] += ((uint64_t*) sendbuf)[t*count+j];
         recvbuf[t*count+j] = acc[j];
      }
      uint32_t i = 1;
      while (i < numberOfNodes) {
         int connfd = connections[i];

         recvCount = 0;
         tempbuf = basetempbuf;

         do {
            n = ::read(connfd, tempbuf, (sizeof(uint64_t)*count) - recvCount);
            if (n < 0) {
               std::cerr << "Could not read: " << n << std::endl;
               ::close(connfd);
               return 1;
            }
            recvCount += n;
            tempbuf +=n;
         } while(recvCount < sizeof(uint64_t)*count);

         //accumulate
         for (int j = 0; j < count; j++) {
            acc[j] += ((uint64_t*) basetempbuf)[j];
         }

         //Send to node i
         //write msg
         if ((n = ::write(connfd, acc, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
            std::cerr << "Could not send" << std::endl;
            ::close(connfd);
            return 1;
         }
         i++;
      }//while
   }//for

   delete[] basetempbuf;
   delete[] acc;
   return 0;
}

int HardRoceCommunicator::masterScanSum64Thread(const uint64_t* sendbuf, uint64_t* recvbuf, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* tempbuf = new char[count*sizeof(uint64_t)];
   char* basetempbuf = tempbuf;
   uint64_t* acc = new uint64_t[count];
   memset(acc, 0, count*sizeof(uint64_t));

   for (uint32_t t = 0; t < numberOfThreads; t++) {

      //accumulate local
      for (int j = 0; j < count; j++) {
         recvbuf[t*count+j] = acc[j];
      }

      uint32_t i = 1;
      while (i < numberOfNodes) {
         int connfd = connections[i];

         recvCount = 0;
         tempbuf = basetempbuf;

         do {
            n = ::read(connfd, tempbuf, (sizeof(uint64_t)*count) - recvCount);
            if (n < 0) {
               std::cerr << "Could not read: " << n << std::endl;
               ::close(connfd);
               return 1;
            }
            recvCount += n;
            tempbuf +=n;
         } while(recvCount < sizeof(uint64_t)*count);

         //Send to node i
         //write msg
         if ((n = ::write(connfd, acc, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
            std::cerr << "Could not send" << std::endl;
            ::close(connfd);
            return 1;
         }//TODO does not work with more than 2 nodes

         //accumulate
         for (int j = 0; j < count; j++) {
            acc[j] += ((uint64_t*) basetempbuf)[j];
         }

         i++;
      }//while
      for (int j = 0; j < count; j++) {
         acc[j] += ((uint64_t*) sendbuf)[t*count+j];
      }
   }//for

   delete[] basetempbuf;
   delete[] acc;
   return 0;
}




int HardRoceCommunicator::slaveScanSum64(const uint64_t* sendbuf, uint64_t* output, uint32_t count) {
   int n = 0;
   int recvCount = 0;
   char* recvbuf = (char*) output;

   for (uint32_t j = 0; j < numberOfThreads; ++j) {
      //write msg
      if ((n = ::write(connections[0], sendbuf, sizeof(uint64_t)*count)) != sizeof(uint64_t)*count)  {
         std::cerr << "Could not send" << std::endl;
         close(connections[0]);
         return 1;
      }
      sendbuf += count;
      recvCount = 0;
      //recvbuf = (char*) (output + (j*count));

      do {
         n = ::read(connections[0], recvbuf, (sizeof(uint64_t)*count) - recvCount);
         if (n < 0) {
            std::cerr << "Could not read: " << n << std::endl;
            ::close(connections[0]);
            return 1;
         }
         recvCount += n;
         recvbuf = ((char*) recvbuf) + n;
      } while (recvCount < sizeof(uint64_t)*count);
   }
   return 0;
}


int HardRoceCommunicator::masterExchangeWindow(RoceWin* win) {
   int n = 0;
   int recvCount = 0;

   for (uint32_t i = 1; i < numberOfNodes; ++i) {
      char* recvPtr = (char*) &(win->windows[i]);
      recvCount = 0;
      //read window
      do {
         n = ::read(connections[i], recvPtr, sizeof(RoceWinMeta)-recvCount);
         if (n < 0) {
            std::cerr << "Could not read window: " << n << std::endl;
            ::close(connections[i]);
            return 1;
         }
         recvPtr += n;
         recvCount += n;
      } while(recvCount < sizeof(RoceWinMeta));
   }//for

   //send accumulated values
   for (uint32_t i = 1; i < numberOfNodes; ++i) {
      //write windows
      for (int j  = 0; j < numberOfNodes; j++) {
         if (i == j) {
            continue;
         }
         if ((n = ::write(connections[i], &(win->windows[j]), sizeof(RoceWinMeta))) != sizeof(RoceWinMeta))  {
            std::cerr << "Could not send" << std::endl;
            ::close(connections[i]);
            return 1;
         }
      }//for
   }//for

   //delete[] basetempbuf;
   return 0;
}


int HardRoceCommunicator::slaveExchangeWindow(RoceWin* win) {
   int n = 0;
   int recvCount = 0;

   //write window
   if ((n = ::write(connections[0], &(win->windows[nodeId]), sizeof(RoceWinMeta))) != sizeof(RoceWinMeta))  {
            std::cerr << "Could not send window" << std::endl;
            ::close(connections[0]);
            return 1;
   }
   //read windows
   for (uint32_t i = 0; i < numberOfNodes; ++i) {
      if (nodeId == i) {
         continue;
      }
      char* recvPtr = (char*) &(win->windows[i]);
      recvCount = 0;
      //read window
      do {
         n = ::read(connections[0], recvPtr, sizeof(RoceWinMeta)-recvCount);
         if (n < 0) {
            std::cerr << "Could not read window: " << n << std::endl;
            ::close(connections[0]);
            return 1;
         }
         recvPtr += n;
         recvCount += n;
      } while(recvCount < sizeof(RoceWinMeta));
   }//for

   return 0;
}

} /* namespace communication */
//} /* namespace hashjoin */

