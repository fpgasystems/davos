/*
 * QueuePair.h
 *
 *  Created on: Nov 13, 2017
 *      Author: dasidler
 */

#ifndef SRC_ROCE_QUEUEPAIR_H_
#define SRC_ROCE_QUEUEPAIR_H_

#include <fpga/IbQueue.h>

namespace roce {

class QueuePair {
public:
   IbQueue   local;
   IbQueue   remote;
};


} /* namespace roce */

#endif /* SRC_ROCE_QUEUEPAIR_H_ */

