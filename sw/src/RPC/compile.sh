#!/bin/bash
####How to compile the codes for the .
g++ -o hashtable_rpc hashtable_rpc.cpp -lnsl  -pthread -mavx -std=c++1y -lboost_program_options

g++ -o linkedlist_rpc linkedlist_rpc.cpp -lnsl  -pthread -mavx -std=c++1y -lboost_program_options

