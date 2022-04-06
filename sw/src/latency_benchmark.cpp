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

void fillRandomData(uint64_t* block, uint64_t size) {
   std::default_random_engine rand_gen(seed);
   std::uniform_int_distribution<int> distr(0, std::numeric_limits<std::uint32_t>::max());

   uint64_t* uPtr = block;
   for (uint64_t i = 0; i < size-7; i += 8) {
      *uPtr = distr(rand_gen);
      uPtr++;
   }
}

int main(int argc, char *argv[]) {

   //command line arguments

   boost::program_options::options_description programDescription("Allowed options");
   programDescription.add_options()("size,s", boost::program_options::value<uint64_t>(), "Transfer size in bytes")
                                    ("repetitions,r", boost::program_options::value<uint32_t>(), "Number of repetitions")
                                    ("messages,m", boost::program_options::value<uint32_t>(), "Number of messages")
                                    ("address", boost::program_options::value<std::string>(), "master ip address")
                                    ("warmup,w", boost::program_options::value<bool>(), "run warm up")
                                    ("isWrite", boost::program_options::value<bool>(), "operation")
                                    ("isLatency", boost::program_options::value<bool>(), "latency");
                                    

   boost::program_options::variables_map commandLineArgs;
   boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
   boost::program_options::notify(commandLineArgs);
   
   int32_t numberOfNodes = 2;
   int32_t nodeId = 0;
   uint64_t transferSize = 0;
   uint32_t numberRepetitions = 1;
   uint32_t numberOfMessages = 10;
   const char* masterAddr = nullptr;
   bool runWarmUp = true;
   bool isWrite = true;
   bool isLatency = false;

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
   if (commandLineArgs.count("isWrite") > 0) {
      isWrite = commandLineArgs["isWrite"].as<bool>();
   }

   if (commandLineArgs.count("isLatency") > 0) {
      isLatency = commandLineArgs["isLatency"].as<bool>();
   }

   std::cout << "tranferSize " << transferSize << std::endl;
   if (isWrite) {
      std::cout << "Running write benchmark" << std::endl;
   } else {
      std::cout << "Running read benchmark" << std::endl;
   }

   if (commandLineArgs.count("address") > 0) {
      nodeId = 1;
      masterAddr = commandLineArgs["address"].as<std::string>().c_str();
      std::cout << "master: " << masterAddr << std::endl;
   }

   fpga::Fpga::setNodeId(nodeId);
   fpga::Fpga::initializeMemory();

   communication::HardRoceCommunicator* communicator = new communication::HardRoceCommunicator(fpga::Fpga::getController(), nodeId, numberOfNodes, 1, masterAddr);

   //Setup buffers and exchange windows
   uint64_t allocSize = transferSize;
   allocSize *= 2;

   uint64_t* dmaBuffer =  (uint64_t*) fpga::Fpga::allocate(allocSize);
   communication::RoceWin* window = (communication::RoceWin*) calloc(1, sizeof(communication::RoceWin));
   communicator->exchangeWindow(dmaBuffer, allocSize, window);


   //sender
   double durationUs = 0.0;
   std::vector<double> durations;

   if (nodeId == 1) {

      fillRandomData(dmaBuffer, transferSize);

      if (!isWrite) {
         communicator->put(dmaBuffer, transferSize, 0, 0, 0, window);
      }

      volatile uint64_t* pollPtr = dmaBuffer;
      pollPtr += (allocSize/sizeof(uint64_t));
      pollPtr--;
     
      for (uint32_t r = 0; r < numberRepetitions+1; ++r) {
         if (r == 0) {
            if (!runWarmUp) {
               continue;
            }
            std::cout << "Warm up..." << std::endl;
         } else {
            std::cout << "Repetition: " << r <<  "/" << numberRepetitions << std::endl;
         }

         memset((void*) pollPtr, 0, 64);
         std::this_thread::sleep_for(5s);

         auto start = std::chrono::high_resolution_clock::now();
         if (isWrite) {
            communicator->put(dmaBuffer, transferSize, 0, 0, 0, window);
         } else {
            communicator->get(dmaBuffer, transferSize, transferSize, 0, 0, window);
         }
         
         while(*pollPtr == 0);
         auto end = std::chrono::high_resolution_clock::now();
         durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);

         if (r != 0) {
            durations.push_back(durationUs);
         }
      }

   } else { //receiver

      volatile uint64_t* pollPtr = dmaBuffer;
      if(isWrite) {
         pollPtr += ((transferSize)/sizeof(uint64_t));
         --pollPtr;
      }else {
         pollPtr += ((allocSize)/sizeof(uint64_t));
         --pollPtr;
      }

      if (isWrite) {
         for (uint32_t r = 0; r < numberRepetitions+1; ++r) {
            if (r == 0 && !runWarmUp) {
               continue;
            }
            //busy polling
            while (*pollPtr == 0);
            //send back
            communicator->put(dmaBuffer, transferSize, 0, 1, transferSize, window);

            std::this_thread::sleep_for(1s);
            memset((void*) pollPtr, 0, 64);
         }
      } else {
         while (*pollPtr == 0);
      }
   }

   if (nodeId == 1) {
      //release the other node
      if (!isWrite) {
         uint64_t targetOffset = transferSize;
         communicator->put(dmaBuffer, transferSize, 0, 0, targetOffset, window);

      }

      //Get stats
      double totalDurationUs = 0.0;
      for (uint32_t r = 0; r < numberRepetitions; ++r) {
         totalDurationUs += durations[r];
      }
      double avgDurationUs = totalDurationUs / (double) numberRepetitions;
      double messageRate =  (((double) numberOfMessages) / avgDurationUs);
      double stddev = 0.0;
      for (uint32_t r = 0; r < numberRepetitions; ++r) {
         double thisMessageRate = ((double) numberOfMessages) / durations[r];
         stddev += ((thisMessageRate - messageRate) * (thisMessageRate - messageRate));
      }
      stddev /= numberRepetitions;
      
      if (isLatency){
         std::sort(durations.begin(), durations.end());
         double min = durations[0];
         double max = durations[numberRepetitions-1];
         double p25 = durations[(numberRepetitions/4)-1];
         double p50 = durations[(numberRepetitions/2)-1];
         double p75 = durations[((numberRepetitions*3)/4)-1];
         double p1 = 0.0;
         double p5 = 0.0;
         double p95 = 0.0;
         double p99 = 0.0;
         double iqr = p75 - p25;
         std::cout << "iqr: " << iqr << std::endl;
         double lower_iqr = p25 - (1.5 * iqr);
         double upper_iqr = p75 + (1.5 * iqr);
         
         if (numberRepetitions >= 100) {
            p1 = durations[((numberRepetitions)/100)-1];
            p5 = durations[((numberRepetitions*5)/100)-1];
            p95 = durations[((numberRepetitions*95)/100)-1];
            p99 = durations[((numberRepetitions*99)/100)-1];
         }
         std::cout<<"Statistics:"<<std::endl;
         std::cout<< min<<" "<<max<<" "<<p1<<" "<<p5<<" "<<p25<<" "<<p50<<" "<<p75<<" "<<p95<<" "<<p99<<" "<<lower_iqr<<" "<<upper_iqr<<std::endl; 
         double pliqr = durations[0];
         double puiqr = durations[0];
         for (uint32_t r = 0; r < numberRepetitions; ++r) {
            pliqr = durations[r];
            if (pliqr > lower_iqr) {
               break;
            }
         }

         for (uint32_t r = 0; r < numberRepetitions; ++r) {
            if (durations[r] > upper_iqr) {
               break;
            }
            puiqr = durations[r];
         }
      }
      std::cout << "Size[B]: " << std::dec << transferSize << std::endl;
      std::cout << "Messages: " << std::dec << numberOfMessages << std::endl;
      std::cout << "Duration[us]: " << avgDurationUs << std::endl;
      std::cout << "Message rate [Msg/us]: " << messageRate << std::endl;
      std::cout << std::fixed << "Message rate [Msg/s]: " << (messageRate * 1000.0 * 1000.0) << std::endl;
      std::cout << "Stddev: " <<stddev << std::endl;

      std::cout << "#" << transferSize << "\t" << messageRate  << "\t" << stddev << std::endl;
   }

   fpga::Fpga::getController()->printDebugRegs();
   fpga::Fpga::getController()->printDmaStatsRegs();

   fpga::Fpga::free(dmaBuffer);
   fpga::Fpga::clear();

   return 0;

}

