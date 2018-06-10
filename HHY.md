# Hints for DPDK and DPDK-based mTCP

DPDK is build on [PSIO](http://shader.kaist.edu/packetshader/io_engine/) or [DPDK](dpdk.org). It's mentioned that only linux kernel 2.6.* supports PSIO ([Ubuntu]() 11.04 or earlier). Hence DPDK is optimal choice.
## DPDK
#### Requirements
 * prepare package `numa` before installing dpdk
#### Environment
For no available physical NICs that support DPDK, I do the setup using ***VMware+Ubuntu-14-LTS***. Create **LAN** *not bridge* that connects to two VMs. 
> I successful install normal DPDK in ***Ubuntu 18*** but if you're to use mTCP-specific DPDK, you're recommended to install it in ***Ubuntu 14/16*** (both ok when I try).
#### INSTALLATION
mTCP requires specific modified version of DPDK which sits inside mTCP folder.
```sh
cd DPDK-17.08
```
##### Hints
---
- `usertools/dpdk-setup.sh` can help you skip most of steps
- if necessary, add `sudo` before commands

##### Details
---
1. configure make envrionment and make DPDK (This can be done by running `usertools/dpdk-setup.sh`)
    ```sh
    make config T=x86_64-native-linuxapp-gcc
    sed -ri 's,(PMD_PCAP=).*,\1y,' build/.config
    make
    ```
2. setup hugepage mappings for non-NUMA systems (Run `usertools/dpdk-setup.sh`) and input a number (e.g. 1024)
3. install igb module (I try to use `usertools/dpdk-setup.sh` but it always failed. It seems another dependent module is always unattached before we load `uio`. So do it manually. )
    ```sh
    sudo modprobe ptp
    sudo modprobe uio
    sudo insmod build/kmod/igb_uio.ko
    ```
    To see what's wrong with it, use command `dmesg |tail`. I saw some errors below.
    ```
    igb_uio: Unknown symbol ptp_clock_index (err 0)
    igb_uio: Unknown symbol ptp_clock_register (err 0)
    ```
    Run command `modprobe ptp` before loading igb will solve it.
4. configure NIC
    * ensure that NICs are DPDK-supported.
    * deactive interfaces before binding them to DPDK
        ``` 
        ifconfig eth* down
        ```
    * bind them to DPDK driver using `usertools/dpdk-setup.sh` (enter **PCI address** for per NIC, e.g. 02:02.0)
5. test your DPDK installation like [DPDK](dpdk.org)
    ```
    sudo ./build/app/testpmd -c7 -n3 -- -i --nb-cores=2 --nb-ports=2
    testpmd> show port stats all
    testpmd> start tx_first
    testpmd> stop
    ```
    > when pressing `stop`, non-zero statistics hit the success 
6. run applications/examples, but it may require some undefined envrionment variables
    ```sh
    $ export RTE_SDK=/home/yml/dpdk/dpdk-*    
    $ export RTE_TARGET=x86_64-native-linuxapp-gcc   
    $ export DESTDIR = /home/yml/dpdk/dpdk-*/ 
    ```

##### Debug   
-----
|   Error    | Solution |
|   -------- | -------- |
|error reading from file descriptor|modify `/lib/librte_eal/linuxapp/igb_uio/igb_uio.c` in the function initializing PCI as ```if (pci_intx_mask_supported(dev))``` ==> ```if (pci_intx_mask_supported(dev) || 1)```|
|invalid numa socket |just ignore|
|No free hugepages reported in ...| just ignore|

___

## mTCP
#### Requirements
- install `autotools-dev`
#### INSTALLATION
1. run `autoconf -fi`
2. configure and make
    ```sh
    $ ./configure --with-dpdk-lib=`echo $PWD`/dpdk
    $ make
    ```
3. run `dpdk-17.08/build/usertools/setup_iface_single_process.sh` and bind IP address to each interfaces
    ```sh
    $ ifconfig $INTERFACE $IP/$MASK up
    ```
4. link folder `dpdk/` to `dpdk-17.08/`
    ```sh
    $ cd dpdk/
    $ ln -s <path_to_dpdk_17_08_directory>/x86_64-native-linuxapp-gcc/lib lib
    $ ln -s <path_to_dpdk_17_08_directory>/x86_64-native-linuxapp-gcc/include include
    ```
5. check configurations in `/apps/example` for examples `epserver` and `epwget`.
    > For the reason that interfaces running at DPDK will no long run in kernel driver. It implies that every packet will not be submitted to kernel or further processed by **kernel TCP stack**. Resulting from this, we should configure route table and arp table manually. These configuration examples are listed as `/config/*.conf`. Just let `epserver` and `epwget` know the path accessing them.
6. run client and server seperately
#### Debug
---
|Error | Hint |
|------|------|
|Cause: Cannot configure device: err=-22, port=0| using ***emulated e1000*** device incurs that only **1 RX** and **1 TX** queue per NIC are supported. Hence add `num_cores = 1` to config files.|
|about **buffer/memory**| These errors always occur in server side. When `max_num_buffers ` or `max_concurrency` is too large, it crashes, I assigned many hugepages though; The same when `rcvbuf` or `sndbuf` is too large. No solutions still.|

#### Results
For limitations for virtual NICs, I config both `epwget` and `epserver` as 
    
    num_cores =1  ## single core
    max_concurrency = 10000
    max_num_buffers = 10000
    rcvbuf = 8196
    sndbuf = 8196

and run `$connections` in client as 1000, 2000, 3000, 4000 respectively. The client is sending requests to fetch fixed-size file (i.e. **64B** txt file) in parallel(multi-connections).
> For `max_concurrency` limit in server, I fail to run too many connections (i.e. 5000) during experiments.

The results(in `hhy_result/`) show that mTCP in our setup (Intel ) performs **twice** better than reports from paper( $$2*10^5$$ transactions per second).
> Different envrionment may contribute to differential results. With VM setup, packet latency should be smaller than true physical setup, although processing rate is less efficient in VMs. Moreover, I didn't set vm configure virtually equivalent to pm since their hardware configs are naturally different.
> I test `ping` using two **virtual** machines (about 0.4 ms) and two **physical** machines(about 1.3ms).









    
