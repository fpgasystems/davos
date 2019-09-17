# DavOS (Distributed Accelerator OS)

## Build project

1. Initialize submodules
```
$ git clone git@github.com:fpgasystems/davos.git
$ git submodule update --init --recursive
```

2. Create build directory
```
$ mkdir build
$ cd build
```

3. Configure build
```
$ cmake .. -DDEVICE_NAME=vcu118 -DTCP_STACK_EN=1 -DVIVADO_ROOT_DIR=/opt/Xilinx/Vivado/2019.1/bin -DVIVADO_HLS_ROOT_DIR=/opt/Xilinx/Vivado/2019.1/bin

```
All options:

| --------------------- | --------------------- | ----------------------------------------------------------------------- |
| Name                  | Values                | Desription                                                              |
| DEVICE_NAME           | <vc709,vcu118,adm7v3> | Supported devices                                                       |
| NETWORK_BANDWIDTH     | <10,100>              | Bandwidth of the Ethernet interface in Gbit/s, default depends on board |
| ROLE_NAME             | <name>                | Name of the role, default:. benchmark_role                              |
| ROLE_CLK              | <net,pcie>            | Main clock used for the role, default: net                              |
| TCP_STACK_EN          | <0,1>                 | default: 0                                                              |
| UDP_STACK_EN          | <0,1>                 | default: 0                                                              |
| ROCE_STACK_EN         | <0,1>                 | default: 0                                                              |
| VIVADO_ROOT_DIR       | <path>                | Path to Vivado HLS directory, e.g. /opt/Xilinx/Vivado/2019.1            |
| VIVADO_HLS_ROOT_DIR   | <path>                | Path to Vivado HLS directory, e.g. /opt/Xilinx/Vivado/2019.1            |


4. Build HLS IP cores and install them into IP repository
```
$ make installip
```

5. Create vivado project
```
$ make project
```

6. Run synthesis
```
$ make synthesize
```

7. Run implementation
```
$ make implementation
```

8. Generate bitstream
```
$ make bitstream
```



## Handling HLS IP cores

1. Setup build directory, e.g. for the dma_bench module

```
$ cd hls/dma_bench
$ mkdir build
$ cd build
$ cmake .. -DFPGA_PART=xcvu9p-flga2104-2L-e -DCLOCK_PERIOD=3.2
```

2. Run c-simulation
```
$ make csim
```

3. Run c-synthesis
```
$ make synthesis
```

4. Generate HLS IP core
```
$ make ip
```

5. Instal HLS IP core in ip repository
```
$ make installip
```
