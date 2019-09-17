/*
 * Communicator.h
 *
 *  Created on: Nov 13, 2017
 *      Author: claudeb
 */

#ifndef SRC_HASHJOIN_COMMUNICATION_COMMUNICATOR_H_
#define SRC_HASHJOIN_COMMUNICATION_COMMUNICATOR_H_

#include <stdint.h>

//#include <hashjoin/core/HashJoinThread.h>
//#include <communication/Window.h>
//#include <hashjoin/histograms/GlobalHistogram.h>

//namespace hashjoin {
namespace communication {

class Communicator {

public:

	virtual ~Communicator() {};

public:

	uint32_t nodeId;
	uint32_t numberOfNodes;
	uint32_t numberOfThreads;

public:

	virtual void connect() = 0;
	virtual void prepare() = 0;

public:

	//virtual void barrier(hashjoin::core::HashJoinThread* thread) = 0;

public:

	/*virtual void reduceAll(uint64_t *input, uint64_t *output, uint32_t numberOfElements, hashjoin::core::HashJoinThread* thread) = 0;
   virtual void reduceAllThread(uint64_t *input, uint64_t *output, uint32_t numberOfElements, hashjoin::core::HashJoinThread* thread) = 0;
	virtual void prefixSum(uint64_t *input, uint64_t *output, uint32_t numberOfElements, hashjoin::core::HashJoinThread* thread) = 0;
   virtual void prefixSumThread(uint64_t *input, uint64_t *output, uint32_t numberOfElements, hashjoin::core::HashJoinThread* thread) = 0;*/

public:

	//virtual Window * createWindow(uint64_t size, bool isOuter=false) = 0;

public:

	//virtual void collectMeasurements(hashjoin::core::HashJoinThread* thread) = 0;

};

} /* namespace communication */
//} /* namespace hashjoin */

#endif /* SRC_HASHJOIN_COMMUNICATION_COMMUNICATOR_H_ */
