# Set up project and cmake
cmake_minimum_required (VERSION 3.1)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake/")

project (DmaDriverExample)

include_directories("${CMAKE_CURRENT_SOURCE_DIR}")

# Set up compilation options
set (CMAKE_CXX_STANDARD 14)
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread -mavx")

set (CMAKE_C_STANDARD 11)

set (CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -pthread -mavx")
set (CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -pthread -mavx")

find_package(Boost COMPONENTS program_options REQUIRED)



# Set up target for main executable
add_executable(dma-example
    main.cpp
    fpga/Fpga.cpp
    fpga/FpgaController.cpp
    fpga/MemoryManager.cpp
    fpga/IbQueue.cpp
    )
target_link_libraries(dma-example
	${Boost_LIBRARIES}
    )

add_executable(iperf-benchmark
    iperf.cpp
    fpga/Fpga.cpp
    fpga/FpgaController.cpp
    fpga/MemoryManager.cpp
    fpga/IbQueue.cpp
    )
target_link_libraries(iperf-benchmark
	${Boost_LIBRARIES}
    )

add_executable(rate-benchmark
    rate_benchmark.cpp
    fpga/Fpga.cpp
    fpga/FpgaController.cpp
    fpga/MemoryManager.cpp
    fpga/IbQueue.cpp
    communication/HardRoceCommunicator.cpp
    )
target_link_libraries(rate-benchmark
	${Boost_LIBRARIES}
    )

add_executable(debug
    debug.cpp
    fpga/Fpga.cpp
    fpga/FpgaController.cpp
    fpga/MemoryManager.cpp
    fpga/IbQueue.cpp
    )
