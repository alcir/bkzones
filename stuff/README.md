# Various scripts to handle SmartOS VMs backup

## listallvmzfs.sh

Print a list of all the ZFS file systems associated to all the virtual machines in a SmartOS global zone

Usage <br />
`./listallvmzfs.sh [-s<0|1>] [-v] [-h]`
``` 
-v  : a little bit more verbose
-s0 : for each ZFS filesystem (related to VMs) print also the snapshots
-s1 : for each ZFS filesystem (related to VMs) print only the snapshots
-h  : this help
```

## listavmszfs.sh

Remotely connect using SSH and keys to a defined list of servers (defined inside the script itself) and launch the `listallvmzfs.sh` script inside each GZ. Then return the list of ZFS filesystems associated to each VM.<br />
Note: `listallvmzfs.sh` script must be installed inside each global zone that must be contacted.

Usage <br />
`./listavmszfs.sh [-t]`
```
    -h  : this help
    -t  : don't print the GZ name before the ZFS list
```

## listoldest.sh

...

## delbk.sh

...
