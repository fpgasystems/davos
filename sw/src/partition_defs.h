


namespace data {
class Tuple {
public:
   uint64_t key;
   uint64_t rid;
};

class CompressedTuple {
public:
   uint64_t value;
};

} /* namespace data */

//Partitioning Configuration
class Configuration {
public:
   static const uint32_t NETWORK_PARTITION_BITS = 10;
   static const uint64_t NETWORK_PARTITION_FANOUT = (1<<NETWORK_PARTITION_BITS);

   static const uint32_t LOCAL_PARTITION_BITS = 10;
   static const uint64_t LOCAL_PARTITION_FANOUT = (1<<LOCAL_PARTITION_BITS);

   static const uint64_t PAYLOAD_BITS = (64-NETWORK_PARTITION_BITS)/2;
};
