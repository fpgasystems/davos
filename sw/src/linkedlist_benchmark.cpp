/**
 * @author  David Sidler <david.sidler@inf.ethz.ch>
 * (c) 2017, ETH Zurich, Systems Group
 *
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <chrono>
#include <thread>
#include <random>
#include <vector>
#include <algorithm>

#include <fpga/Fpga.h>
#include <communication/Communicator.h>
#include <communication/HardRoceCommunicator.h>

#include <boost/program_options.hpp>

using namespace std::chrono_literals;

static unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();

struct ListElement {
   uint64_t key;
   ListElement* next;
   void* value_ptr;
};

void createLinkedList(unsigned char* block, uint64_t remoteBaseAddr, uint64_t numElements, uint64_t valueSize) {
   std::default_random_engine rand_gen(seed);
   std::uniform_int_distribution<int> distr(0, std::numeric_limits<std::uint32_t>::max());
	
   //std::cout << "----------------- LINKED LIST ----------" << std::endl;
   uint64_t localBaseAddr = (uint64_t) block;
   ListElement* ePtr = (ListElement*) block;
   ListElement* nextPtr;
   uint64_t* valuePtr = (uint64_t*) (block + sizeof(ListElement) * numElements);
   //align to next cacheline
   if (((uint64_t)valuePtr) % 64 != 0) {
      valuePtr += 8;
      valuePtr -= (((uint64_t) valuePtr % 64) / sizeof(uint64_t));
   }
   for (uint32_t e = 0; e < numElements; ++e) {
      ePtr->key = distr(rand_gen);
      ePtr->value_ptr = (void*) (remoteBaseAddr + (((uint64_t) valuePtr) - localBaseAddr));
      nextPtr = (ePtr + 1);
      ePtr->next = (ListElement*) (remoteBaseAddr + (((uint64_t) nextPtr) - localBaseAddr));
      //std::cout << std::dec << "Element[" << e << "] key: " << std::hex << ePtr->key << " -> " << ePtr->value_ptr << ", next: " << ePtr->next << std::endl;
      ePtr++;
      for (uint64_t i = 0; i < valueSize-7; i += 8) {
         *valuePtr = distr(rand_gen);
         valuePtr++;
      }
      
   }
   //std::cout << "--------------------------------- END ----------" << std::endl;
}

void printList(ListElement* head) {
	
   std::cout << "----------------- LINKED LIST ----------" << std::endl;
   ListElement* ePtr = head;
   size_t e = 0;
   while (ePtr != nullptr)
   {
      std::cout << std::dec << "Element[" << e << "] key: " << std::hex << ePtr->key << " -> " << ePtr->value_ptr << ", next: " << ePtr->next << std::endl;
      ePtr = ePtr->next;
      e++;
   }
   std::cout << "--------------------------------- END ----------" << std::endl;
}


int main(int argc, char *argv[]) {

   //command line arguments

   boost::program_options::options_description programDescription("Allowed options");
   programDescription.add_options()("queries,q", boost::program_options::value<int>(), "Number of queries per iteration")
                                    ("elements,e", boost::program_options::value<int>(), "Number of Elements in hash table")
                                    ("valuesize,s", boost::program_options::value<int>(), "Value size in bytes for latency, kilobytes for thhroughput")
                                    //("repetitions,r", boost::program_options::value<int>(), "Number of repetitions")
                                    ("address", boost::program_options::value<std::string>(), "master ip address")
                                    ("warmup,w", boost::program_options::value<bool>(), "warm up")
                                    ("offload,o", boost::program_options::value<bool>(), "offload pointer chasing");


   boost::program_options::variables_map commandLineArgs;
   boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
   boost::program_options::notify(commandLineArgs);
   
   int32_t numberOfNodes = 2;
   int32_t nodeId = 0;
   uint32_t numberOfQueries = 1;
   uint32_t numberOfElements = 1;
   uint32_t valueSize = 64;
   uint32_t numberRepetitions = 1;
   bool usePtrChase = false;
   const char* masterAddr = nullptr;
   bool runWarmup = true;
   
   if (commandLineArgs.count("queries") > 0) {
      numberOfQueries = commandLineArgs["queries"].as<int>();
   } else {
      std::cerr << "argument missing";
      return 1;
   }

   if (commandLineArgs.count("elements") > 0) {
      numberOfElements = commandLineArgs["elements"].as<int>();
   } else {
      std::cerr << "argument missing";
      return 1;
   }


   if (commandLineArgs.count("valuesize") > 0) {
      valueSize = commandLineArgs["valuesize"].as<int>();
   } else {
      std::cerr << "argument missing";
      return 1;
   }

   /*if (commandLineArgs.count("repetitions") > 0) {
      numberRepetitions = commandLineArgs["repetitions"].as<int>();
   }*/

   if (commandLineArgs.count("address") > 0) {
      nodeId = 1;
      masterAddr = commandLineArgs["address"].as<std::string>().c_str();
      std::cout << "master: " << masterAddr << std::endl;
   }
   if (commandLineArgs.count("warmup") > 0) {
      runWarmup = commandLineArgs["warmup"].as<bool>();
   }

   if (commandLineArgs.count("offload") > 0) {
      usePtrChase = commandLineArgs["offload"].as<bool>();
   }


   std::cout << "Number of Queries: " << numberOfQueries << std::endl;
   std::cout << "Number of Elements: " << numberOfElements << std::endl;
   std::cout << "Value Size: " << valueSize << std::endl;
   //TODO some checks on valueSize
   //assert(sizeof(HashTableEntry) == 64);
   uint64_t ListElementsSize = numberOfElements * sizeof(ListElement);
   if (ListElementsSize % 64 != 0) {
      ListElementsSize += (64 - (ListElementsSize % 64));
   }
   uint64_t ListValuesSize = numberOfElements * valueSize;
   std::cout << std::dec << "element size: " << ListElementsSize << ", values size: " << ListValuesSize << std::endl;
   uint64_t LinkedListSize = ListElementsSize + ListValuesSize;
   std::cout << std::dec << "linked list size: " << LinkedListSize << std::endl;
   uint64_t resultSize = numberOfQueries * valueSize + 64; //sizeof(ListElement);
   uint64_t allocSize = LinkedListSize + resultSize;
   std::cout << "allocation size: " << allocSize << std::endl;


   fpga::Fpga::setNodeId(nodeId);
   fpga::Fpga::initializeMemory();

   communication::HardRoceCommunicator* communicator = new communication::HardRoceCommunicator(fpga::Fpga::getController(), nodeId, numberOfNodes, 1, masterAddr);
   //net::Network::initialize(fpga::Fpga::getController(), nodeId, numberOfNodes, masterAddr);

   //Setup buffers and exchange windows
   uint64_t* dmaBuffer =  (uint64_t*) fpga::Fpga::allocate(allocSize);
   communication::RoceWin* window = (communication::RoceWin*) calloc(1, sizeof(communication::RoceWin));
   communicator->exchangeWindow(dmaBuffer, allocSize, window);

   //sender
   double durationNs = 0.0;
   std::vector<double> durations;
   std::vector<uint32_t> queryIndexes;

   if (nodeId == 1) {
      std::default_random_engine rand_gen(seed);
      std::uniform_int_distribution<int> distr(0, numberOfElements-1);


      uint64_t remoteBaseAddr = (uint64_t) (window->windows[0].base);
      createLinkedList((unsigned char*) dmaBuffer, (uint64_t) remoteBaseAddr, numberOfElements, valueSize);

      volatile ListElement* headPtr = (ListElement*) dmaBuffer;
      volatile ListElement* elementPtr = (ListElement*) (dmaBuffer + (LinkedListSize/sizeof(uint64_t)));
      unsigned char* valuePtr = (unsigned char*) dmaBuffer;
      valuePtr += (LinkedListSize);
      valuePtr += 64; //sizeof(ListElement);
      uint64_t entryOffset = 0;
      uint64_t valueOffset = 0;

      //write data to remote node
      communicator->put(dmaBuffer, LinkedListSize, 0, 0, 0, window);

      //read all hash table entries and values
      for (uint32_t r = 0; r < numberRepetitions+1; ++r) {
         //volatile ListElement* ePtr = elementPtr;
         entryOffset = 0;
         unsigned char* vPtr = valuePtr;
         if (r == 0) {
            if (!runWarmup)
                  continue;
            std::cout << "Warm up..." << std::endl;
         } else {
            std::cout << "Repetition: " << r <<  "/" << numberRepetitions << std::endl;
         }
         memset((void*) (dmaBuffer+(LinkedListSize/sizeof(uint64_t))), 0, resultSize);
         queryIndexes.clear();
         queryIndexes.reserve(numberOfQueries);

         std::this_thread::sleep_for(2s);
         //auto start = std::chrono::high_resolution_clock::now();

         for (uint32_t q = 0; q < numberOfQueries; ++q) {
            //std::cout << "Query: " << q << std::endl;
      
            uint32_t randOffset = distr(rand_gen); 
            queryIndexes.push_back(randOffset);
            //key
            uint64_t requestedKey = headPtr[randOffset].key;
            //ePtr = elementPtr;
            entryOffset = 0;
            //entryOffset = randOffset * sizeof(HashTableEntry); 

            auto start = std::chrono::high_resolution_clock::now();

            if (!usePtrChase) {
               do {
                  elementPtr->key = 0;
                  communicator->get((void*) elementPtr, sizeof(ListElement), 0, 0, entryOffset, window);
                  //wait for list element
                  //std::cout << "polling" << std::endl;
                  while(elementPtr->key == 0) {};
                  //std::cout << std::dec << q << ": " << std::hex << ePtr->key << " -> " << ePtr->value_ptr << std::endl;
                  entryOffset += sizeof(ListElement);
               } while(elementPtr->key != requestedKey);

               uint64_t valueOffset = (uint64_t) (((uint64_t) elementPtr->value_ptr) - remoteBaseAddr);
               //std::cout << std::dec << "valueOffset: " << valueOffset << std::hex << ", valuePtr: " << ePtr->value_ptr << std::endl;

               //fetch value
               communicator->get((void*) vPtr, valueSize, 0, 0, valueOffset, window);

            } else {
               //Offload Pointer Chasing
               /*keyPtr = (HashTableEntry*) dmaBuffer;
               keyPtr += randOffset; //TODO merge*/
               uint16_t mask = 0x1;
               //PredicateOp op = EQUAL;
               uint8_t ptrOffset = 4;
               communicator->getValueForKeyAt((void*) vPtr, valueSize, 0, 0, entryOffset, window, requestedKey, mask, ptrOffset, false, 2, true);
            }

            vPtr += valueSize;
            volatile uint64_t* valuePollPtr = (uint64_t*)vPtr;
            valuePollPtr--;
//std::cout << "polling for value, valuPollPtr: "<< std::hex << valuePollPtr << std::endl;
            while (*valuePollPtr == 0) {};
            auto end = std::chrono::high_resolution_clock::now();
            durationNs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
            if (r != 0) {
               durations.push_back(durationNs);
            }

         }
      }


   } else { //receiver

      volatile uint64_t* pollPtr = dmaBuffer;
      pollPtr += (LinkedListSize/sizeof(uint64_t));
      --pollPtr;

      //busy polling, waiting for hash table data to be written
      while (*pollPtr == 0);

      //waiting for release
      while (*pollPtr != 0) {
         std::this_thread::sleep_for(1s);
      }

   }

   //Verify correctness
   if (nodeId == 1) {
      //printHashTable((unsigned char*) dmaBuffer, numberOfElements, valueSize);
      //printHashTable((((unsigned char*) dmaBuffer) + hashTableSize), numberOfElements, valueSize);

      bool correct = true;
      uint64_t bytesTested = 0;
      unsigned char* resultPtr = (((unsigned char*) dmaBuffer) + LinkedListSize);
      resultPtr += 64; //sizeof(ListElement);
      for (uint32_t q = 0; q < numberOfQueries; q++) {
         uint32_t offset = queryIndexes[q];
         unsigned char* expectedValuePtr = ((unsigned char*) dmaBuffer) + (numberOfElements * sizeof(ListElement));
         if (((uint64_t) expectedValuePtr) % 64 != 0) {
            expectedValuePtr += (64 - (((uint64_t) expectedValuePtr) % 64));
         }
         expectedValuePtr += (offset * valueSize);
         for (uint32_t j = 0; j < valueSize; ++j) {
            if (resultPtr[j] != expectedValuePtr[j]) {
               std::cout << std::dec << "Byte[" << j << "] in value of query " << q << " does not match, expected: ";
               std::cout << std::hex << (uint16_t) expectedValuePtr[j] << ", received: " << (uint16_t)resultPtr[j] << std::endl;
               correct = false;
            }
            bytesTested++;
         }
         resultPtr += valueSize;
      }
      if (correct) {
         std::cout << "RESULT CORRECT " << std::dec << bytesTested << " bytes tested.\n";
      }

      //release the other node
      memset((void*) dmaBuffer, 0, LinkedListSize);
      communicator->put(dmaBuffer, LinkedListSize, 0, 0, 0, window);

      //Get stats
      double totalDurationNs = 0.0;
      for (uint32_t r = 0; r < numberOfQueries; ++r) {
         totalDurationNs += durations[r];
         //std::cout << "duration[" << r << "]: " << durations[r] << std::endl;
      }
      double avgDurationNs = totalDurationNs /(double)numberOfQueries;
      double stddev = 0.0;
      for (uint32_t r = 0; r < numberOfQueries; ++r) {
         stddev += ((durations[r] - avgDurationNs) * (durations[r] - avgDurationNs));
      }
      stddev /= numberOfQueries;
      std::sort(durations.begin(), durations.end());
      double min = durations[0];
      double max = durations[numberOfQueries-1];
      double p25 = durations[(numberOfQueries/4)-1];
      double p50 = durations[(numberOfQueries/2)-1];
      double p75 = durations[((numberOfQueries*3)/4)-1];
      double p1 = 0.0;
      double p5 = 0.0;
      double p95 = 0.0;
      double p99 = 0.0;
      double iqr = p75 - p25;
      std::cout << "iqr: " << iqr << std::endl;
      double lower_iqr = p25 - (1.5 * iqr);
      double upper_iqr = p75 + (1.5 * iqr);
      if (numberOfQueries >= 100) {
         p1 = durations[((numberOfQueries)/100)-1];
         p5 = durations[((numberOfQueries*5)/100)-1];
         p95 = durations[((numberOfQueries*95)/100)-1];
         p99 = durations[((numberOfQueries*99)/100)-1];
      }
      double pliqr = durations[0];
      double puiqr = durations[0];
      for (uint32_t r = 0; r < numberOfQueries; ++r) {
         pliqr = durations[r];
         if (pliqr > lower_iqr) {
            break;
         }
      }
      for (uint32_t r = 0; r < numberOfQueries; ++r) {
         if (durations[r] > upper_iqr) {
            break;
         }
         puiqr = durations[r];
      }
      /*for (uint32_t r = 0; r < numberOfQueries; ++r) {
         std::cout << "duration[" << r << "]: " << std::fixed << durations[r] << std::endl;
      }*/

      std::cout << "Size[B]: " << std::dec << valueSize << std::endl;
      std::cout << std::fixed << "Duration[us]: " << avgDurationNs << std::endl;
      std::cout << std::fixed << "Min: " << min << std::endl;
      std::cout << std::fixed << "Max: " << max << std::endl;
      std::cout << std::fixed << "Median: " << p50 << std::endl;
      std::cout << std::fixed << "1th: " << p1 << std::endl;
      std::cout << std::fixed << "5th: " << p5 << std::endl;
      std::cout << std::fixed << "25th: " << p25 << std::endl;
      std::cout << std::fixed << "75th: " << p75 << std::endl;
      std::cout << std::fixed << "95th: " << p95 << std::endl;
      std::cout << std::fixed << "99th: " << p99 << std::endl;
      std::cout << std::fixed << "Lower IQR: " << pliqr << std::endl;
      std::cout << std::fixed << "Upper IQR: " << puiqr << std::endl;
      std::cout << std::fixed << "Duration stddev: " << stddev << std::endl;
      //double throughput = (((double) (transferSize*8)/(avgDurationNs)));
      //std::cout << std::fixed << "Throughput[Gbit/s]: " << throughput << std::endl;
      std::cout << std::fixed << "#" << numberOfElements << "\t" << numberOfQueries  << "\t" << valueSize << "\t" << avgDurationNs;
      std::cout << "\t" << min << "\t" << max << "\t";
      std::cout << p1 << "\t" << p5 << "\t" << p25 << "\t" << p50 << "\t" << p75 << "\t" << p95 << "\t" << p99 << "\t";
      std::cout << pliqr << "\t" << puiqr << "\t" << stddev << std::endl;

   }

	fpga::Fpga::getController()->printDebugRegs();
   fpga::Fpga::getController()->printDmaStatsRegs();

   fpga::Fpga::free(dmaBuffer);
   fpga::Fpga::clear();

	return 0;

}

