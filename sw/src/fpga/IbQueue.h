/*
 * IbQueue.h
 *
 *  Created on: Nov 13, 2017
 *      Author: dasidler
 */

#ifndef SRC_ROCE_IBQUEUE_H_
#define SRC_ROCE_IBQUEUE_H_

//#include <stdint.h>
#include <cstdint>
#include <string>
#include <cstring>

namespace roce {


class IbQueue {
public:
   IbQueue() { memset(gid, 0, 33); }

   std::uint32_t   qpn;
   std::uint32_t   psn;
   std::uint32_t   rkey;
   std::uint64_t   vaddr;
   std::uint32_t   size;
   char            gid[33];

   std::string encode();
   void decode(char* buf, size_t len);
   void print(const char* name);
   uint32_t gidToUint(int idx);
   void uintToGid(int idx, uint32_t);
};

} /* namespace roce */

#endif /* SRC_ROCE_IBQUEUE_H_ */

