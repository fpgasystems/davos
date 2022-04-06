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
#include <communication/HardRoceCommunicator.h>

#include <boost/program_options.hpp>

#define HASH_BIT_MODULO(NUMBER, DIGITMASK, SHIFTBITS) (((NUMBER) & (DIGITMASK)) >> (SHIFTBITS))

using namespace std::chrono_literals;

//static unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();

void fillData(uint64_t* block, uint64_t sizeInTuples) {
   //std::default_random_engine rand_gen(seed);
   //std::uniform_int_distribution<int> distr(0, std::numeric_limits<std::uint32_t>::max());

   data::Tuple* tPtr = (data::Tuple*) block;
   for (uint64_t i = 0; i < sizeInTuples; ++i) {
      tPtr->key = (i*2);
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

bool checkNetworkPartCorrectness(data::Tuple* tPtr, data::CompressedTuple* cPtr, uint64_t sizeInTuples)
{
   bool correct = true;
   const uint64_t MASK = (uint64_t(1) << (Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS)) - 1;

   for (uint64_t i = 0; i < sizeInTuples; ++i) {
      uint64_t rid = (cPtr->value & MASK);
      uint64_t key = ((cPtr->value >> (Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS)) << Configuration::NETWORK_PARTITION_BITS);      

      //std::cout << "rid: " << rid << "key: " << key << std::endl;
      if (key != tPtr->key || rid != tPtr->rid) {
         std::cout << "Not matching value[" << std::dec << i << "] at address: ";
         std::cout << std::hex << cPtr << ", expected: (" << tPtr->rid << "," << tPtr->key;
         std::cout << ") received: (" << rid << "," << key << ")" << std::endl;
         correct = false;
      }
      tPtr++;
      cPtr++;
   }
   return correct;
}

void printNetworkPart(data::CompressedTuple* cPtr, uint64_t sizeInTuples)
{
   const uint64_t MASK = (uint64_t(1) << (Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS)) - 1;

   for (uint64_t i = 0; i < sizeInTuples; ++i) {
      uint64_t rid = (cPtr->value & MASK);
      uint64_t key = ((cPtr->value >> (Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS)) << Configuration::NETWORK_PARTITION_BITS);      

      std::cout << std::dec << i << std::hex << "\trid: " << rid << "key: " << key << std::endl;
      cPtr++;
   }
}


bool checkLocalPartCorrectness(uint64_t baseAddr, uint64_t* histogram, uint64_t* prefixSum)
{
   bool correct = true;
   uint64_t partitionId = 0;
   uint64_t MASK = (Configuration::LOCAL_PARTITION_FANOUT - 1) << (Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS);

   for (uint32_t p = 0; p < Configuration::LOCAL_PARTITION_FANOUT; ++p) {
      uint64_t count = histogram[p];
      if (count > 0)
      {
         data::CompressedTuple* cPtr = (data::CompressedTuple*) (baseAddr + (prefixSum[p] * sizeof(data::CompressedTuple)));
         //printf("--- Partition %u ------ \n", p);
         for (uint32_t i = 0; i < count; ++i) {

            uint64_t currPartitionId = HASH_BIT_MODULO(cPtr->value, MASK, Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS);
            if (partitionId != currPartitionId) {
               std::cout << std::dec << "In partition: " << partitionId << " @";
               std::cout << std::hex << baseAddr + (prefixSum[p] * sizeof(data::CompressedTuple)) <<  ", entry " << std::dec << i+1 << "/" << count;
               std::cout << ", wrong partitionID: " << currPartitionId << std::endl;
               correct = false;
            }
            
            //std::cout << std::hex << "rid: " << rid << " key: " << key << std::endl;
            cPtr++;
         }
      }
      partitionId++;
   }
   return correct;
}

void printLocalPart(uint64_t baseAddr, uint64_t* histogram, uint64_t* prefixSum)
{
   const uint64_t MASK = (uint64_t(1) << (Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS)) - 1;

   for (uint32_t p = 0; p < Configuration::LOCAL_PARTITION_FANOUT; ++p) {
      uint64_t count = histogram[p];
      data::CompressedTuple* cPtr = (data::CompressedTuple*) (baseAddr + (prefixSum[p] * sizeof(data::CompressedTuple)));
      printf("--- Partition %u ------ \n", p);
      for (uint32_t i = 0; i < count; ++i) {
         uint64_t rid = (cPtr->value & MASK);
         uint64_t key = ((cPtr->value >> (Configuration::NETWORK_PARTITION_BITS + Configuration::PAYLOAD_BITS)) << Configuration::NETWORK_PARTITION_BITS);         
         std::cout << std::dec << i << std::hex << "\trid: " << rid << " key: " << key << std::endl;
         cPtr++;
      }
   }
}



int main(int argc, char *argv[]) {
   //command line arguments

   boost::program_options::options_description programDescription("Allowed options");
   programDescription.add_options()("useLocal", boost::program_options::value<bool>(), "use local & network partitioner")
                                 ("tuples,t", boost::program_options::value<uint32_t>(), "number of tuples in thousands")
                                 ("repetitions,r", boost::program_options::value<uint32_t>(), "number of repetitions")
                                 ("print,p", boost::program_options::value<bool>(), "print result")
                                 ("id", boost::program_options::value<uint32_t>(), "node id")
                                 ("warmup,w", boost::program_options::value<bool>(), "warm up");
   boost::program_options::variables_map commandLineArgs;
   boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
   boost::program_options::notify(commandLineArgs);
   
   uint32_t nodeId = 0;
   uint64_t sizeInTuples = 0;
   uint32_t numberRepetitions = 10;
   bool testLocalPart = false;
   bool printOutput = false;
   bool runWarmup = true;

   if (commandLineArgs.count("id") > 0) {
      nodeId = commandLineArgs["id"].as<uint32_t>();
   }

   
   if (commandLineArgs.count("tuples") > 0) {
      sizeInTuples = commandLineArgs["tuples"].as<uint32_t>();
      sizeInTuples *= 1000;
   } else {
      std::cerr << "tuples required.\n";
      return -1;
   }

   if (commandLineArgs.count("repetitions") > 0) {
      numberRepetitions = commandLineArgs["repetitions"].as<uint32_t>();
   }

   if (commandLineArgs.count("useLocal") > 0) {
      testLocalPart = commandLineArgs["useLocal"].as<bool>();
   }

   if (commandLineArgs.count("print") > 0) {
      printOutput = commandLineArgs["print"].as<bool>();
   }
   if (commandLineArgs.count("warmup") > 0) {
      runWarmup = commandLineArgs["warmup"].as<bool>();
   }


   //Check multiple of 8

   uint64_t inputSize = sizeInTuples * sizeof(data::Tuple);
   uint64_t outputSize = sizeInTuples * sizeof(data::CompressedTuple);

   std::cout << "Number of Tuples " << sizeInTuples << std::endl;
   std::cout << "Input size " << ((double) inputSize)/1024.0/1024.0 << "MB" << std::endl;
   std::cout << "Output size " << ((double) outputSize)/1024.0/1024.0 << "MB" <<  std::endl;

   //init
   fpga::Fpga::setNodeId(nodeId);
   fpga::Fpga::initializeMemory();
   fpga::FpgaController* controller = fpga::Fpga::getController();
   controller->resetDmaWrites();
   controller->resetDmaReads();
   controller->resetPartitionTuples();
   controller->setBoardNumber(nodeId);

   //Setup buffers and exchange windows
   uint64_t allocSize = inputSize + outputSize;
   
   uint64_t* dmaBuffer =  (uint64_t*) fpga::Fpga::allocate(allocSize);

   //Set up histogram
   uint64_t addr;
   uint64_t baseAddr = ((uint64_t) dmaBuffer) + (inputSize);
   //round to 2MB
   baseAddr = ((baseAddr + 2097151) / 2097152) * 2097152;
   uint64_t* prefixSum = new uint64_t[Configuration::LOCAL_PARTITION_FANOUT];
   uint64_t* histogram = new uint64_t[Configuration::LOCAL_PARTITION_FANOUT];

   //sender
   double durationUs = 0.0;
   std::vector<double> durations;

   fillData(dmaBuffer, sizeInTuples);
   if (testLocalPart) {
      calculatePrefixSum(dmaBuffer, sizeInTuples, histogram, prefixSum);
   }

   uint64_t expected = 0;
   for (uint32_t r = 0; r < numberRepetitions+1; ++r) {
      controller->resetDmaWrites();
      controller->resetDmaReads();
      expected = 0;

      if (r == 0) {
         if (!runWarmup)
            continue;
         std::cout << "Warm up..." << std::endl;
      } else {
         std::cout << "Repetition: " << r <<  "/" << numberRepetitions << std::endl;
      }
      //memset((void*) pollPtr+1, 0, dataSize);
      printf("nework partitioner output address: %p\n", baseAddr);
      controller->setPartitionerMapping(fpga::direction::TX, 0, 0x11, baseAddr);
      for (uint64_t i = 1; i < Configuration::NETWORK_PARTITION_FANOUT; ++i) {
         addr = (baseAddr + (outputSize));
         controller->setPartitionerMapping(fpga::direction::TX, i, 0x11, addr);
      }
      if (testLocalPart) {
         for (uint64_t i = 0; i < Configuration::LOCAL_PARTITION_FANOUT; ++i) {
            //std::cout << "prefixSum[" << i << "]: " << prefixSum[i];
            //std::cout << "\thistogram[" << i << "]:" << histogram[i] << std::endl;
            addr = baseAddr + (prefixSum[i] * sizeof(data::CompressedTuple));
            controller->setPartitionerMapping(fpga::direction::RX, i, 0x11, addr);
         }
         controller->writePartitionCmd(fpga::direction::RX, fpga::appOpCode::APP_PART, 0, (uint32_t) sizeInTuples * sizeof(data::CompressedTuple));
      }

      std::this_thread::sleep_for(1s);
      expected += outputSize;
      printf("partition cmd, addr: %p, size: %lu\n", dmaBuffer, inputSize);

      auto start = std::chrono::high_resolution_clock::now();
      if (!testLocalPart) {
         controller->writePartitionCmd(fpga::direction::TX, fpga::appOpCode::APP_WRITE, (uint64_t) dmaBuffer, inputSize);
      } else {
         controller->writePartitionCmd(fpga::direction::TX, fpga::appOpCode::APP_PART, (uint64_t) dmaBuffer, inputSize);
      }

      uint64_t received = controller->getDmaWrites();
      //printf("received: %lu, expected: %lu\n", received, expected);
      while (received < expected) {
         std::this_thread::sleep_for(std::chrono::microseconds(1));
         received = controller->getDmaWrites();
         //printf("received: %lu, expected: %lu\n", received, expected);
      }
      auto end = std::chrono::high_resolution_clock::now();
      durationUs = std::chrono::duration_cast<std::chrono::microseconds>(end-start).count();
      if (r != 0) {
         durations.push_back(durationUs);
      }
   }
   
   //Verify correctness
   bool correct = false;
   if (!testLocalPart)
   {
      correct = checkNetworkPartCorrectness((data::Tuple*) dmaBuffer, (data::CompressedTuple*) baseAddr, sizeInTuples);
      if (printOutput) {
         printNetworkPart((data::CompressedTuple*) baseAddr, sizeInTuples);
      }

   } else {
      correct = checkLocalPartCorrectness(baseAddr, histogram, prefixSum);
      if (printOutput) {
         printLocalPart(baseAddr, histogram, prefixSum);
      }
   }
   if (correct) {
      std::cout << "RESULT CORRECT\n";
   }


   //Get stats
   double totalDurationUs = 0.0;
   for (uint32_t r = 0; r < numberRepetitions; ++r) {
      totalDurationUs += durations[r];
      printf("durations[%u]: %f\n", r, durations[r]);
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
      double p25 = 0;
      double p75 = 0;
      if (numberRepetitions > 1) {
         p25 = durations[(numberRepetitions/4)-1];
         p75 = durations[((numberRepetitions*3)/4)-1];
      }

      std::cout << std::fixed << "Size[MB]: " << std::dec << (((double) inputSize)/1024.0/1024.0) << std::endl;
      std::cout << std::fixed << "Duration[us]: " << avgDurationUs << std::endl;
      std::cout << std::fixed << "Min: " << min << std::endl;
      std::cout << std::fixed << "Max: " << max << std::endl;
      std::cout << std::fixed << "25th: " << p25 << std::endl;
      std::cout << std::fixed << "75th: " << p75 << std::endl;
      std::cout << std::fixed << "Duration stddev: " << stddev << std::endl;
      //std::cout << "Latency[us]: " << avgDurationUs/2.0 << std::endl;
      double throughput = ((((double) inputSize)/1024.0/1024.0/1024.0)/(avgDurationUs/1000.0/1000.0));
      std::cout << std::fixed << "Throughput[GiB/s]: " << throughput << std::endl;
      std::cout << std::fixed << "Throughput[GB/s]: " << ((double) inputSize)/avgDurationUs/1000.0 << std::endl;
      std::cout << std::fixed<< "#" << sizeInTuples << "\t" << ((double) inputSize)/1024.0/1024.0/1024.0 << "\t" << avgDurationUs << "\t" << min << "\t" << max << "\t" << p25 << "\t" << p75 << "\t" << stddev << "\t" << throughput << "\t" << ((double) inputSize)/avgDurationUs/1000.0 << std::endl;


	controller->printDebugRegs();
   controller->printDmaStatsRegs();

   fpga::Fpga::free(dmaBuffer);
   fpga::Fpga::clear();

   delete[] prefixSum;
   delete[] histogram;

	return 0;

}

