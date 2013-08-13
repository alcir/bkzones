# Various scripts to handle SmartOS VMs backup


## listallvmzfs.sh

Print a list of all the ZFS file systems associated to all the virtual machines in a SmartOS global zone

Usage
./listallvmzfs.sh [-s<0|1>] [-v] [-h]
 
    -v  : a little bit more verbose
    -s0 : for each ZFS filesystem (related to VMs) print also the snapshots
    -s1 : for each ZFS filesystem (related to VMs) print only the snapshots
    -h  : this help
