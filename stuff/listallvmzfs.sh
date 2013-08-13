#!/bin/bash

#List all the ZFS file systems associated to all the virtual machines

while read xuuid
do

  zoneuid=$xuuid

  vmadm get $zoneuid | json zfs_filesystem

  while read disk
  do

    echo $disk

  done < <(vmadm get $zoneuid | json disks | grep zfs_filesystem | awk -F"\"" '{print $4}')

  while read dataset
  do

    echo $dataset

  done < <(vmadm get $zoneuid | json datasets | json -a)


done < <(vmadm list -p -o uuid)
