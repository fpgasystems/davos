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

#include <hpcjoin/data/Tuple.h>
#include <boost/program_options.hpp>
#include <sstream>
#include <iomanip>
#include <iostream>

#include "hyperloglog64_avx.h"
#include "cardinality.h"

#define HASH64
#define HLL_SW
 
using namespace std::chrono_literals;

union ulf
{
    unsigned long ul;
    float f;
};

struct Tuple {
   uint32_t value;
};

typedef struct {
    hll_thread_args_t* hll_thread;
    uint32_t memSize;
    uint32_t* addr;
    uint32_t threads;
    uint32_t chunk;
} hll_chunk_args_t;


void fillRandomData(uint64_t* block, uint64_t size) {
   uint64_t* uPtr = block;
   for (uint64_t i = 0; i < size-7; i +=8) {
      *uPtr = ((i+1)<<32) + i; 
      uPtr++;
   }
}

void* hll_chunk(void* args)  {

   hll_chunk_args_t* a = (hll_chunk_args_t*)args;
   uint32_t memSizeB = a->memSize;
   uint32_t iterationsPerThread = memSizeB/a->chunk/a->threads;
   //std::cout<<"TEST iteration per thread"<<iterationsPerThread<<std::endl;
   uint32_t* endAddr = a->addr + memSizeB/sizeof(uint32_t) - 1;
   //std::cout<<"TEST end address"<<endAddr<<std::endl;  

   for (uint32_t i = 0; i<iterationsPerThread; i++) {
      
       volatile uint32_t* startAddr = a->addr + i*a->threads*a->chunk/sizeof(uint32_t);    
       volatile uint32_t* pollAddr = startAddr + a->chunk/sizeof(uint32_t) - 1;
       
       if (pollAddr <= endAddr) {
           a->hll_thread->m_input = (int*)startAddr;
           a->hll_thread->m_num_items = a->chunk/sizeof(uint32_t);

           while(*pollAddr==0);
          
           hll64_thread((void*)(a->hll_thread));
       }
   }
}

template< typename T >
std::string int_to_hex( T i )
{
  std::stringstream stream;
  stream << "0x" 
         << std::setfill ('0') << std::setw(sizeof(T)*2) 
         << std::hex << i;
  return stream.str();
}

int main(int argc, char *argv[]) {

   //command line arguments

   boost::program_options::options_description programDescription("Allowed options");
   programDescription.add_options()("size,s", boost::program_options::value<uint64_t>(), "Transfer size in bytes")
                                    ("repetitions,r", boost::program_options::value<uint32_t>(), "Number of repetitions")
                                    ("messages,m", boost::program_options::value<uint32_t>(), "Number of messages")
                                    ("address", boost::program_options::value<std::string>(), "master ip address")
                                    ("threads,t", boost::program_options::value<uint32_t>(), "Number of threads")
                                    ("chunk,p", boost::program_options::value<uint32_t>(), "Size of a chunk")
                                    ("warmup,w", boost::program_options::value<bool>(), "run warm up")
                                   // ("isWrite", boost::program_options::value<bool>(), "operation")
                                    ("cardinality,c", boost::program_options::value<uint32_t>(), "cardinality");

   boost::program_options::variables_map commandLineArgs;
   boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
   boost::program_options::notify(commandLineArgs);
   
   int32_t numberOfNodes = 2;
   int32_t nodeId = 0;
   uint64_t transferSize = 0;
   uint32_t numberRepetitions = 1;
   uint32_t numberOfMessages = 10;
   const char* masterAddr = nullptr;

   bool runWarmUp = false;
   bool isWrite = true;
   uint32_t cardinality = 2;
   
   uint32_t NUM_THREADS = 1;
   uint32_t CHUNK_SIZE_B = 20000000;   
 
   if (commandLineArgs.count("size") > 0) {
      transferSize = commandLineArgs["size"].as<uint64_t>();
   } else {
      std::cerr << "argument missing";
      return 1;
   }
   if (commandLineArgs.count("repetitions") > 0) {
      numberRepetitions = commandLineArgs["repetitions"].as<uint32_t>();
   }

   if (commandLineArgs.count("messages") > 0) {
      numberOfMessages = commandLineArgs["messages"].as<uint32_t>();
   }
   if (commandLineArgs.count("warmup") > 0) {
      runWarmUp = commandLineArgs["warmup"].as<bool>();
   }

   if (commandLineArgs.count("cardinality") > 0) {
      cardinality = commandLineArgs["cardinality"].as<uint32_t>();
   }                                                                                          
   
   if (commandLineArgs.count("threads") > 0) { 
     NUM_THREADS = commandLineArgs["threads"].as<uint32_t>();

     if (NUM_THREADS > 8){
       std::cerr << "maximum number of threads is 8" <<std::endl;
       NUM_THREADS = 8;
     } 
   }
   
   if (commandLineArgs.count("chunk") > 0) {
      CHUNK_SIZE_B = commandLineArgs["chunk"].as<uint32_t>();
   }
 
 //hll-sw -start
 #ifdef HLL_SW 
   uint32_t num_items = numberOfMessages*transferSize/4;

   int** buckets_global = (int**)malloc(NUM_THREADS*sizeof(int*));
   for (uint32_t i = 0; i < NUM_THREADS; i++) {
        buckets_global[i] = (int*)_mm_malloc(NUM_BUCKETS_M*sizeof(int), 64);
        // reset
        for (uint32_t j = 0; j < NUM_BUCKETS_M; j++) {
            buckets_global[i][j] = 0;
        }
   }
   int* buckets_final = (int*)malloc(NUM_BUCKETS_M*sizeof(int));
   for (uint32_t j = 0; j < NUM_BUCKETS_M; j++) {
        buckets_final[j] = 0;
   }
   
   hll_chunk_args_t* argvs = (hll_chunk_args_t*)malloc(NUM_THREADS*sizeof(hll_chunk_args_t));
   
   for (int i=0; i<NUM_THREADS; i++){
      argvs[i].hll_thread = (hll_thread_args_t*)malloc(sizeof(hll_thread_args_t));
   }
   
   pthread_t* threads = (pthread_t*)malloc(NUM_THREADS*sizeof(pthread_t));
   
 #endif 
 //hll-sw -end

   std::cout << "TranferSize: " << transferSize << "[B]" <<std::endl;
      
   if (commandLineArgs.count("address") > 0) {
      nodeId = 1;
      masterAddr = commandLineArgs["address"].as<std::string>().c_str();
      std::cout << "Master address: " << masterAddr << std::endl;
   } else {
      std::cout << "Cardinality: " << cardinality << std::endl;
   }

   if (isWrite) {
      std::cout << "Action: write data" << std::endl;
   } else {
      std::cout << "Action: read data" << std::endl;
   }

   fpga::Fpga::setNodeId(nodeId);
   fpga::Fpga::initializeMemory();
   
   fpga::FpgaController* controller = fpga::Fpga::getController();
   controller->resetDmaWrites();
   controller->resetDmaReads();

   communication::HardRoceCommunicator* communicator = new communication::HardRoceCommunicator(controller, nodeId, numberOfNodes, 1, masterAddr);

   // setup buffers and exchange windows
   uint64_t allocSize = 2000000000;
   uint64_t allocSizeResult = allocSize + 4;

   uint64_t* dmaBuffer =  (uint64_t*) fpga::Fpga::allocate(allocSizeResult);
   communication::RoceWin* window = (communication::RoceWin*) calloc(1, sizeof(communication::RoceWin));
   communicator->exchangeWindow(dmaBuffer, allocSize, window);
   
   // set memory to zero
   memset(dmaBuffer, 0, allocSizeResult);

   // result of the HLL module
   volatile uint32_t* resultPtr = (uint32_t*)(dmaBuffer + allocSize/sizeof(uint64_t) + 2);
   
   // send to HLL module the number of values and pointer result 
   controller->hllParameters(transferSize*numberOfMessages/4, (uint32_t*)(resultPtr));

   // execution duration vector 
   double durationUs = 0.0;
   std::vector<double> durations;

   if (nodeId == 1) { //transmitter

      fillRandomData(dmaBuffer, transferSize);
      
      // set polling pointer 
      volatile uint64_t* pollPtr = dmaBuffer;

      if (isWrite) {
         pollPtr += (numberOfMessages*transferSize/sizeof(uint64_t));
      } 

      for (uint32_t r = 0; r < numberRepetitions+1; r++) {
         if (r == 0) {
            if (!runWarmUp) {
               continue;
            }
            std::cout << "Warm up..." << std::endl;
         } else {
            std::cout << "Repetition: " << r <<  "/" << numberRepetitions << std::endl;
         }

         memset((void*) pollPtr, 0, 8);

         std::this_thread::sleep_for(5s);

         auto start = std::chrono::high_resolution_clock::now();
         if (isWrite) {
            for (uint32_t m = 0; m < numberOfMessages; m++) {
               communicator->put(dmaBuffer, transferSize, 0, 0, (0 + m*transferSize), window);
            }
         }

          while(*pollPtr == 0);
          auto end = std::chrono::high_resolution_clock::now();
          durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);

          if (r != 0) {
             durations.push_back(durationUs);
          }
      }

   } else { //receiver
      volatile uint64_t* pollPtrS= dmaBuffer;

      volatile uint64_t* pollPtr = dmaBuffer;
      pollPtr += (numberOfMessages*transferSize)/sizeof(uint64_t) - 1;
      memset((void*) pollPtrS, 0, 8);
      memset((void*) pollPtr, 0, 8);

      if (isWrite) {
         //no repetitions for the receiver side 
         #ifndef HLL_SW
            std::cout<<"Wait for HLL result! "<<std::endl;
            memset((void*) resultPtr, 0, 4);
            
            //busy polling
            // start of the reception region in memory
            while (*pollPtrS == 0); 
            auto start = std::chrono::high_resolution_clock::now();

            // wait for the result 
            while (*resultPtr == 0);           
            auto end = std::chrono::high_resolution_clock::now();
            
            durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
            durations.push_back(durationUs);

        #endif
   
        //hll-sw -start
        #ifdef HLL_SW
            std::cout<<"HLL_SW"<<std::endl;
            while (*pollPtrS == 0);
            
            auto start_sw = std::chrono::high_resolution_clock::now();

            for (uint32_t i = 0; i < NUM_THREADS; i++) {
               argvs[i].hll_thread->m_buckets = buckets_global[i];
               argvs[i].memSize = num_items*4;
               argvs[i].threads = NUM_THREADS;
               argvs[i].chunk   = CHUNK_SIZE_B;
               argvs[i].addr    = (uint32_t*)(dmaBuffer + i*CHUNK_SIZE_B/sizeof(uint64_t));
               //std::cout<<i<<" TEST Start Address:"<<argvs[i].addr <<std::endl;
               pthread_create(&threads[i], NULL, hll_chunk, (void*)&argvs[i]);
            }
        
            for (uint32_t i = 0; i < NUM_THREADS; i++) {
               pthread_join(threads[i], NULL);
            } 

            for (uint32_t i = 0; i < NUM_THREADS; i++) {
              for (uint32_t j = 0; j < NUM_BUCKETS_M; j++) {
                 if (buckets_global[i][j] > buckets_final[j]) {
                    buckets_final[j] = buckets_global[i][j];
                 }
              }
            }

            double cardinality_sw = calculate_cardinality(buckets_final);
            auto end_sw = std::chrono::high_resolution_clock::now();

            double time_sw_us = (std::chrono::duration_cast<std::chrono::nanoseconds>(end_sw-start_sw).count())/1000.0;

            std::cout << "HLL-SW time[us]: " << time_sw_us << std::endl;
            std::cout << "HLL-SW cardinality result: " << cardinality_sw << std::endl;
            float std_error = (((float)cardinality_sw - (float)cardinality) / (float) cardinality) * 100;
            std::cout << "HLL-SW standard error: " << std_error << std::endl;
            std::cout << "HLL-SW throughput[GB/s]: " << ((double) transferSize*numberOfMessages)/time_sw_us/1000.0<< std::endl;
        #endif
        //hll-sw -end      
         
        //send back
        communicator->put(dmaBuffer, 8, 0, 1, numberOfMessages*transferSize, window);
        std::this_thread::sleep_for(1s);
      
      }
   }
  

   if (nodeId == 1) {
      // get stats
      double totalDurationUs = 0.0;
      for (uint32_t r = 0; r < numberRepetitions; ++r) {
         totalDurationUs += durations[r];
      }
      double avgDurationUs = totalDurationUs / (double) numberRepetitions;
      double messageRate =  (((double) numberOfMessages) / avgDurationUs);
      double stddev = 0.0;
      for (uint32_t r = 0; r < numberRepetitions; r++) {
         double thisMessageRate = ((double) numberOfMessages) / durations[r];
         stddev += ((thisMessageRate - messageRate) * (thisMessageRate - messageRate));
      }
      stddev /= numberRepetitions;

      std::cout << "Size[B]: " << std::dec << transferSize << std::endl;
      std::cout << "Messages: " << std::dec << numberOfMessages << std::endl;
      std::cout << "Duration[us]: " << avgDurationUs << std::endl;
      std::cout << "Message rate [Msg/us]: " << messageRate << std::endl;
      std::cout << std::fixed << "Message rate [Msg/s]: " << (messageRate * 1000.0 * 1000.0) << std::endl;
      std::cout << "Stddev: " <<stddev << std::endl;

      std::cout << "#" << transferSize << "\t" << messageRate  << "\t" << stddev << std::endl;
   }
   else
   {
     #ifndef HLL_SW
       uint32_t sizeInTuples = transferSize*numberOfMessages/4;
       std::cout << std::fixed << "Throughput[GB/s] : " << ((double) transferSize*numberOfMessages)/durations[0]/1000.0 << std::endl;
       std::cout << "Cardinality hex format: "<<std::hex<<*resultPtr<< std::endl;
  
       ulf u;
  
       std::string str = int_to_hex<uint32_t>(*resultPtr);
       std::stringstream ss(str);
       ss >> std::hex >> u.ul;
       float f = u.f;
       std::cout  << "Cardinality Floating Point format: "<< f << std::endl;
       float std_error = (((float)cardinality - (float)f) / (float)cardinality)*100;
       std::cout  << "Standard Error: "<< std::fixed<<std::setprecision(5)<<std_error<<"%" << std::endl;
    #endif
   }

   controller->printDebugRegs();
   controller->printDmaStatsRegs();

   fpga::Fpga::free(dmaBuffer);
   fpga::Fpga::clear();

 //hll-sw -start
 #ifdef HLL_SW  
   for (uint32_t i = 0; i < NUM_THREADS; i++) {
      _mm_free(buckets_global[i]);
   }
   
   free(buckets_global);
   free(buckets_final);
   free(argvs);
   free(threads);
   
 #endif
 //hll-sw -end

   return 0;
}



