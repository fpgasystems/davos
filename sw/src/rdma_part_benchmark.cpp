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

#include <partition_defs.h>
#include <fpga/Fpga.h>
#include <communication/Communicator.h>
#include <communication/HardRoceCommunicator.h>

#include <boost/program_options.hpp>

#define HASH_BIT_MODULO(NUMBER, DIGITMASK, SHIFTBITS) (((NUMBER) & (DIGITMASK)) >> (SHIFTBITS))

using namespace std::chrono_literals;

static unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();

void fillData(uint64_t* block, uint64_t sizeInTuples, uint32_t nodeId) {
   //std::default_random_engine rand_gen(seed);
   //std::uniform_int_distribution<int> distr(0, std::numeric_limits<std::uint32_t>::max());

   data::Tuple* tPtr = (data::Tuple*) block;
   for (uint64_t i = 0; i < sizeInTuples; ++i) {
      tPtr->key = (i * 2)+1+nodeId;
      tPtr->rid = i;
      tPtr++;
   }
}

void calculatePrefixSum(uint64_t* block, uint64_t sizeInTuples, uint64_t* histogram, uint64_t* prefix) {

   memset(histogram, 0, sizeof(uint64_t) * Configuration::LOCAL_PARTITION_FANOUT);
   data::Tuple* tPtr = (data::Tuple*) block;
   for (uint64_t i = 0; i < sizeInTuples; ++i) {
      uint64_t partitionId = HASH_BIT_MODULO((tPtr->key >> Configuration::NETWORK_PARTITION_BITS), (Configuration::LOCAL_PARTITION_FANOUT) - 1, 0);
      //printf("key: %lx -> partition: %lu\n", tPtr->key, partitionId);
      histogram[partitionId]++;
      tPtr++;
   }
  
   uint64_t sum = 0;
   for (uint32_t i = 0; i < Configuration::LOCAL_PARTITION_FANOUT; ++i) {
      prefix[i] = sum;
      sum += histogram[i];
      if (sum % 8 != 0) {
         sum += (sum % 8);
      }
   }

}

int main(int argc, char *argv[]) {

   //command line arguments

   boost::program_options::options_description programDescription("Allowed options");
   programDescription.add_options()("size,s", boost::program_options::value<uint64_t>(), "Transfer size in bytes for latency, kilobytes for thhroughput")
                                    ("repetitions,r", boost::program_options::value<uint32_t>(), "Number of repetitions")
                                    ("throughput,t", boost::program_options::value<bool>(), "do throughput benchmark")
                                    ("address", boost::program_options::value<std::string>(), "master ip address")
                                    ("receiveonly", boost::program_options::value<bool>(), "receive only");
                                    ("warmup,w", boost::program_options::value<bool>(), "run warm up");

   boost::program_options::variables_map commandLineArgs;
   boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
   boost::program_options::notify(commandLineArgs);
   
   int32_t numberOfNodes = 2;
	int32_t nodeId = 0;
   uint64_t transferSize = 0;
   uint32_t numberRepetitions = 1;
   const char* masterAddr = nullptr;
   bool isTpBench = false;
   bool runWarmUp = true;
   bool isReceiveOnly = false;

   if (commandLineArgs.count("size") > 0) {
      transferSize = commandLineArgs["size"].as<uint64_t>();
   } else {
      std::cerr << "argument missing";
      return 1;
   }

   if (commandLineArgs.count("repetitions") > 0) {
      numberRepetitions = commandLineArgs["repetitions"].as<uint32_t>();
   }
   if (commandLineArgs.count("throughput") > 0) {
      isTpBench = commandLineArgs["throughput"].as<bool>();
   }
   if (commandLineArgs.count("receiveonly") > 0) {
      isReceiveOnly = commandLineArgs["receiveonly"].as<bool>();
   }
   if (commandLineArgs.count("warmup") > 0) {
      runWarmUp = commandLineArgs["warmup"].as<bool>();
   }

   if (isTpBench) {
      transferSize *= 1024;
   }
   uint64_t sizeInTuples = transferSize / sizeof(data::Tuple);
   std::cout << "tranferSize " << transferSize << std::endl;
   std::cout << "size in tuples " << sizeInTuples << std::endl;

   if (commandLineArgs.count("address") > 0) {
      nodeId = 1;
      masterAddr = commandLineArgs["address"].as<std::string>().c_str();
      std::cout << "master: " << masterAddr << std::endl;
   }

   fpga::Fpga::setNodeId(nodeId);
   fpga::Fpga::initializeMemory();
   fpga::FpgaController* controller = fpga::Fpga::getController();
   controller->resetDmaWrites();
   controller->resetDmaReads();
   controller->resetPartitionTuples();

   communication::HardRoceCommunicator* communicator = new communication::HardRoceCommunicator(fpga::Fpga::getController(), nodeId, numberOfNodes, 1, masterAddr);

   //Setup buffers and exchange windows
   uint64_t roundedTransferSize = ((transferSize + 2097151) / 2097152) * 2097152;
   uint64_t allocSize = roundedTransferSize;

   if (!isTpBench) {
      allocSize *= 3;
   } else {
      allocSize += 64;
   }

   uint64_t* dmaBuffer =  (uint64_t*) fpga::Fpga::allocate(allocSize);
   communication::RoceWin* window = (communication::RoceWin*) calloc(1, sizeof(communication::RoceWin));
   communicator->exchangeWindow(dmaBuffer, allocSize, window);

   uint64_t* localOffsets = new uint64_t[Configuration::LOCAL_PARTITION_FANOUT];
   uint64_t* localHistogram = new uint64_t[Configuration::LOCAL_PARTITION_FANOUT];

   fillData(dmaBuffer, sizeInTuples, nodeId);
   calculatePrefixSum(dmaBuffer, sizeInTuples, localHistogram, localOffsets);
   for (uint32_t p = 0; p < Configuration::LOCAL_PARTITION_FANOUT; ++p) {
      localOffsets[p] += (roundedTransferSize / sizeof(data::CompressedTuple));
   }

   //sender
   double durationUs = 0.0;
   std::vector<double> durations;

   if (nodeId == 1) {

      uint64_t expected = 0;
      volatile uint64_t* pollPtr = dmaBuffer;
      pollPtr += (roundedTransferSize/sizeof(uint64_t));
      for (uint32_t r = 0; r < numberRepetitions+1; ++r) {
         if (r == 0) {
            if (!runWarmUp) {
               continue;
            }
            std::cout << "Warm up..." << std::endl;
         } else {
            std::cout << "Repetition: " << r <<  "/" << numberRepetitions << std::endl;
         }
         if (!isReceiveOnly) {
            uint64_t netOffsets[2];
            netOffsets[0] = transferSize;
            netOffsets[1] = transferSize;
            communicator->loadNetworkHistogram(netOffsets, window);
         }

         if (!isTpBench) {
            //set up network histogram
            communicator->loadLocalHistogram(nodeId, localOffsets, window, sizeInTuples);
         } else {
            memset((void*) pollPtr, 0, 64);
         }

         std::this_thread::sleep_for(2s);
         expected = sizeInTuples*sizeof(data::CompressedTuple);
         auto start = std::chrono::high_resolution_clock::now();
         if (isReceiveOnly) {
            communicator->localPart(dmaBuffer, sizeInTuples*sizeof(data::Tuple), 0, 0, 0, window);
         } else {
            communicator->networkLocalPart(dmaBuffer, sizeInTuples*sizeof(data::Tuple), (communication::HardRoceWindow*) window);
         }
         if (!isTpBench) {
            communicator->checkWrites(expected);
         } else {
            while(*pollPtr == 0) {};
         }

         auto end = std::chrono::high_resolution_clock::now();
         durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
         if (r != 0) {
            durations.push_back(durationUs);
         }
      }

   } else { //receiver
      uint64_t expected = 0;
      for (uint32_t r = 0; r < numberRepetitions+1; ++r) {
         if (r == 0 && !runWarmUp) {
            continue;
         }
         //set up histogram
         if (!isTpBench && !isReceiveOnly) {
            uint64_t netOffsets[2];
            netOffsets[0] = transferSize;
            netOffsets[1] = transferSize;
            communicator->loadNetworkHistogram(netOffsets, window);
         }
         communicator->loadLocalHistogram(nodeId, localOffsets, window, sizeInTuples);

         //busy polling
         expected = sizeInTuples * sizeof(data::CompressedTuple);
         communicator->checkWrites(expected);
         /*data::CompressedTuple* tPtr = (data::CompressedTuple*) dmaBuffer;
         tPtr += (roundedTransferSize / sizeof(data::CompressedTuple));

         for (uint32_t i = 0; i < sizeInTuples; ++i) {
            printf("value[%i] %lu\n", i, tPtr->value);
            tPtr++;
         }*/
         //send back
         if (!isTpBench) {
            if (isReceiveOnly) {
               communicator->localPart(dmaBuffer, sizeInTuples*sizeof(data::Tuple), 0, 0, 0, window);
            } else {
               communicator->networkLocalPart(dmaBuffer, sizeInTuples*sizeof(data::Tuple), (communication::HardRoceWindow*) window);
            }
         } else {
            communicator->put(dmaBuffer, 8, 0, 1, roundedTransferSize, window);
         }

         std::this_thread::sleep_for(1s);
         //memset(dmaBuffer, 0, transferSize);
      }
   }

   //Verify correctness
   if (nodeId == 1) {
      if (!isTpBench) {
         /*bool correct = true;
         for (uint64_t i = 0; i < (transferSize/8); ++i) {
            if (dmaBuffer[i] != dmaBuffer[(transferSize/8)+i]) {
               std::cout << "Not matching value at " << i << ", expected: " << dmaBuffer[i] << ", received: " << dmaBuffer[(transferSize/8)+i] << std::endl;
               correct = false;
            }
         }
         if (correct) {
            std::cout << "RESULT CORRECT\n";
         }*/
      }

      //Get stats
      double totalDurationUs = 0.0;
      for (uint32_t r = 0; r < numberRepetitions; ++r) {
         totalDurationUs += durations[r];
         //std::cout << "duration[" << r << "]: " << durations[r] << std::endl;
      }
      double avgDurationUs = totalDurationUs /(double)numberRepetitions;
      double stddev = 0.0;
      for (uint32_t r = 0; r < numberRepetitions; ++r) {
         stddev += ((durations[r] - avgDurationUs) * (durations[r] - avgDurationUs));
      }
      stddev /= numberRepetitions;
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
      /*for (uint32_t r = 0; r < numberRepetitions; ++r) {
         std::cout << "duration[" << r << "]: " << std::fixed << durations[r] << std::endl;
      }*/

      std::cout << "Size[B]: " << std::dec << transferSize << std::endl;
      std::cout << std::fixed << "Duration[us]: " << avgDurationUs << std::endl;
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

      std::cout << std::fixed << "#" << numberRepetitions  << "\t" << transferSize << "\t" << avgDurationUs;
      std::cout << "\t" << min << "\t" << max << "\t";
      std::cout << p1 << "\t" << p5 << "\t" << p25 << "\t" << p50 << "\t" << p75 << "\t" << p95 << "\t" << p99 << "\t";
      std::cout << pliqr << "\t" << puiqr << "\t" << stddev << std::endl;

      if (isTpBench) {
         double throughput = ((double) (transferSize*8)/(avgDurationUs));
         std::cout << "Throughput[Gbit/s]: " << throughput << std::endl;
         std::cout << std::fixed << "@" << transferSize << "\t" << avgDurationUs << "\t" << throughput << "\t" << stddev << std::endl;
         std::cout << "Size[MB]: " << std::dec << transferSize/1024 << std::endl;
      }

   }

	fpga::Fpga::getController()->printDebugRegs();
   fpga::Fpga::getController()->printDmaStatsRegs();

   fpga::Fpga::free(dmaBuffer);
   fpga::Fpga::clear();

   delete[] localOffsets;
   delete[] localHistogram;

	return 0;

}

