/*
 * IbQueue.cpp
 *
 *  Created on: Nov 13, 2017
 *      Author: dasidler
 */

#include "IbQueue.h"

#include <iostream>
#include <sstream>
#include <fstream>
#include <iomanip>
#include <cstring>
#include <netdb.h>

namespace roce {

uint32_t IbQueue::gidToUint(int idx) {
   if (idx > 24) {
      std::cerr << "invalid index for gitToUint" << std::endl;
      return 0;
   }
   char tmp[9];
   memset(tmp, 0, 9);
   uint32_t v32 = 0;
   memcpy(tmp, gid+idx, 8);
   sscanf(tmp, "%x", &v32);
   return ntohl(v32);
}

void IbQueue::uintToGid(int idx, uint32_t ipAddr) {
   std::ostringstream gidStream;
   gidStream << std::setfill('0') << std::setw(8) << std::hex << ipAddr;
   memcpy(gid+idx, gidStream.str().c_str(), 8);
}

void IbQueue::print(const char* conn_name) {
   printf("%s:  LID 0x%04x, QPN 0x%06x, PSN 0x%06x, GID %s\n",
         conn_name, 0, qpn, psn, gid);
   printf("RKey %#08x VAddr %016lx\n", rkey, vaddr);
}

std::string IbQueue::encode() {
   std::uint32_t lid = 0;
   std::ostringstream msgStream;
   msgStream << std::setfill('0') << std::setw(4) << std::hex << lid << ":";
   msgStream << std::setfill('0') << std::setw(6) << std::hex << qpn << ":";
   msgStream << std::setfill('0') << std::setw(6) << std::hex << (psn & 0xFFFFFF) << ":";   
   msgStream << std::setfill('0') << std::setw(8) << std::hex << rkey << ":";
   msgStream << std::setfill('0') << std::setw(16) << std::hex << vaddr << ":";
   msgStream << gid;

   std::string msg = msgStream.str();
   return msg;
}

void IbQueue::decode(char* buf, size_t len) {
   if (len < 45) {
      std::cerr << "unexpected length " << len << " in decode ib connection\n";
      return;
   }
   buf[4] = ' ';
   buf[11] = ' ';
   buf[18] = ' ';
   buf[27] = ' ';
   buf[44] = ' ';
   std::uint32_t lid = 0;
	//std::cout << "buf " << buf << std::endl;
	std::string recvMsg(buf, len);
	 //std::cout << "string " << recvMsg << ", length: " << recvMsg.length() << std::endl;
	std::istringstream recvStream(recvMsg);
	recvStream >> std::hex >> lid >> qpn >> psn;
	recvStream >> std::hex >> rkey >> vaddr >> gid;
}

} /* namespace roce */

