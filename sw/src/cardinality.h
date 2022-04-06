#ifndef HASH64
#else
#include "hyperloglog64_avx.h"
#endif
#include <math.h>

double bias_harmonic_mean (int buckets[], int *count_1){
    double ret_val = 0;
    //const float alpha = 0.697; //for m = 32, number of buckets
    const float alpha = 0.7213/(1+(1.079/NUM_BUCKETS_M)); //for m >= 128, number of buckets
    double summation = 0.0;
    int i;
    int count_local = 0;
    //Stochastic average
    for (i = 0; i < NUM_BUCKETS_M; i++) {
           // printf("\n bucekt_val = %d", buckets[i]);
            summation = summation + (double)(1.0/(pow(2,buckets[i])));
            if (buckets[i] == 0)
                count_local++;
    }
    *count_1 = count_local;
    ret_val =  (alpha * NUM_BUCKETS_M * NUM_BUCKETS_M) / summation;
    return ret_val;
}

double calculate_cardinality (int* buckets) {
    double raw_cardinality = 0;
    double estimated_cardinality = 0;
    int count_1;

    //call the bias harmonic mean calculator
    raw_cardinality = bias_harmonic_mean(buckets, &count_1);

    //Conditioning the raw cardinality
    if (raw_cardinality <= 2.5*NUM_BUCKETS_M){
        // Linear counting
        if(count_1 != 0){
            estimated_cardinality = NUM_BUCKETS_M*log((float)NUM_BUCKETS_M / (float)count_1);
        }
        else{
            estimated_cardinality = raw_cardinality;
        }
    }
    else if (raw_cardinality <= (float)(CONST_TWO_POWER_32 / 30)){
        estimated_cardinality = raw_cardinality;
    }
    else {
        estimated_cardinality = (-CONST_TWO_POWER_32)*log (1 - (raw_cardinality / CONST_TWO_POWER_32));
    }
    return estimated_cardinality;
}
