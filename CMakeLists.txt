# Author:   David Sidler (david.sidler@inf.ethz.ch)

cmake_minimum_required(VERSION 3.0)

project(davos)

# Include custom Find<Module>.cmake scripts to enable searching for Vivado HLS                                
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_SOURCE_DIR}/cmake)  

# Check if parent directory
get_directory_property(hasParent PARENT_DIRECTORY)

if (DEFINED ENV{IPREPO_DIR})
   set(IPREPO_DIR $ENV{IPREPO_DIR})
elseif (NOT IPREPO_DIR)
   set(IPREPO_DIR ${CMAKE_CURRENT_SOURCE_DIR}/iprepo)
   message("set iprepor dir ${IPREPO_DIR}")
endif()

# Configuration
# check DEVICE_NAME
# TODO apply FORCE only when parent??
if (DEVICE_NAME STREQUAL "vc709")
   set(FPGA_PART xc7vx690tffg1761-2 CACHE STRING "FPGA part" FORCE)
   set(FPGA_FAMILY 7series CACHE STRING "FPGA family" FORCE)
   set(NETWORK_BANDWIDTH 10 CACHE STRING "Network bandwidth")
   set(DATA_WIDTH 8 CACHE STRING "Network stack data width")
endif()
if (DEVICE_NAME STREQUAL "vcu118")
   set(FPGA_PART xcvu9p-flga2104-2L-e CACHE STRING "FPGA part" FORCE)
   set(FPGA_FAMILY ultraplus CACHE STRING "FPGA family" FORCE)
   set(NETWORK_BANDWIDTH 100 CACHE STRING "Network bandwidth")
   set(DATA_WIDTH 64 CACHE STRING "Network stack data width")
endif()
if (DEVICE_NAME STREQUAL "adm7v3")
   set(FPGA_PART xc7vx690tffg1157-2 CACHE STRING "FPGA part" FORCE)
   set(FPGA_FAMILY 7series CACHE STRING "FPGA family" FORCE)
   set(NETWORK_BANDWIDTH 10 CACHE STRING "Network bandwidth")
   set(DATA_WIDTH 8 CACHE STRING "Network stack data width")
endif()
set(ROLE_CLK net CACHE STRING "role clock")
set(ROLE_NAME benchmark_role CACHE STRING "Role name")

#Network stack config
set(TCP_STACK_EN 0 CACHE BOOL "Enable TCP/IP stack")
set(UDP_STACK_EN 0 CACHE BOOL "Enable UDP/IP stack")
set(ROCE_STACK_EN 0 CACHE BOOL "Enable RoCEv2 stack")

# set bandwidth
if (NETWORK_BANDWIDTH STREQUAL "10")
   if (NOT DEFINED NETWORK_INTERFACE)
      set(NETWORK_INTERFACE 10)
   endif()
   if (NOT DEFINED CLOCK_PERIOD)
      set(CLOCK_PERIOD 6.4)
   endif()
endif()
if (NETWORK_BANDWIDTH STREQUAL "100")
   if (NOT DEFINED NETWORK_INTERFACE)
      set(NETWORK_INTERFACE 100)
   endif()
   if (NOT DEFINED CLOCK_PERIOD)
      set(CLOCK_PERIOD 3.2)
   endif()
endif()



#Network stack IPs
add_subdirectory(ext/network)

#HLS IPs
add_subdirectory(hls/dma_bench)
add_subdirectory(hls/ethernet_frame_padding)
add_subdirectory(hls/ethernet_frame_padding_512)
add_subdirectory(hls/mem_cmd_data_merger_512)
add_subdirectory(hls/mem_read_cmd_merger_512)
add_subdirectory(hls/mem_write_cmd_page_boundary_check_512)
add_subdirectory(hls/tlb)



# Vivado Project

# Find Xilinx Vivado
find_package(Vivado REQUIRED)
if (NOT VIVADO_FOUND)
   message(FATAL_ERROR "Vivado not found.")
endif()
 
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/hdl/common/role_wrapper.sv.in ${CMAKE_BINARY_DIR}/role_wrapper.sv)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/hdl/common/davos_config.svh.in ${CMAKE_BINARY_DIR}/davos_config.svh)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/create_project.tcl.in ${CMAKE_BINARY_DIR}/create_project.tcl)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/run_synthesis.tcl.in ${CMAKE_BINARY_DIR}/run_synthesis.tcl)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/run_implementation.tcl.in ${CMAKE_BINARY_DIR}/run_implementation.tcl)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/generate_bitstream.tcl.in ${CMAKE_BINARY_DIR}/generate_bitstream.tcl)

set (PROJECT_DEPENDS
      ${CMAKE_CURRENT_SOURCE_DIR}/hdl/common/role_wrapper.sv.in
      ${CMAKE_CURRENT_SOURCE_DIR}/scripts/create_project.tcl.in
      ${CMAKE_CURRENT_SOURCE_DIR}/ext/network/scripts/network_stack.tcl
      ${CMAKE_CURRENT_SOURCE_DIR}/scripts/axi_infrastructure.tcl
      ${CMAKE_CURRENT_SOURCE_DIR}/scripts/dma_ultraplus.tcl
      ${CMAKE_CURRENT_SOURCE_DIR}/scripts/dram_ultraplus.tcl
      ${CMAKE_CURRENT_SOURCE_DIR}/scripts/network_ultraplus.tcl
      ${CMAKE_SOURCE_DIR}/scripts/${ROLE_NAME}.tcl)

add_custom_target(project
   COMMAND ${VIVADO_BINARY} -mode batch -source ${CMAKE_BINARY_DIR}/create_project.tcl
   DEPENDS ${PROJECT_DEPENDS})

add_custom_target(synthesize
   COMMAND ${VIVADO_BINARY} -mode batch -source ${CMAKE_BINARY_DIR}/run_synthesis.tcl
   DEPENDS ${PROJECT_DEPENDS})

add_custom_target(implementation
   COMMAND ${VIVADO_BINARY} -mode batch -source ${CMAKE_BINARY_DIR}/run_implementation.tcl
   DEPENDS ${PROJECT_DEPENDS})

add_custom_target(bitstream
   COMMAND ${VIVADO_BINARY} -mode batch -source ${CMAKE_BINARY_DIR}/generate_bitstream.tcl
   DEPENDS ${PROJECT_DEPENDS})

