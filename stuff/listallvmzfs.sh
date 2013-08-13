#!/bin/bash

$VERSION = '0.0.2';

##########################################################################################
##########################################################################################
##########################################################################################
#
# Written by alciregi@gmail.com
#
##########################################################################################

# List all the ZFS file systems associated to all the virtual machines


SNAPSHOT=0
VERBOSE=0
SNAPONLY=0

usage() {
  echo "Version $VERSION"
  echo " "
  echo Usage
  echo "./listallvmzfs.sh [-s<0|1>] [-v] [-h]"
  echo " "
  echo "    -v  : a little bit more verbose"
  echo "    -s0 : for each ZFS filesystem (related to VMs) print also the snapshots"
  echo "    -s1 : for each ZFS filesystem (related to VMs) print only the snapshots"
  echo "    -h  : this help"
  echo " "
  exit 1
}

while getopts "vs:h" opt; do
  case $opt in
    s)
      SNAPSHOT=1
      if [ "x$OPTARG" == "x1" ]; then SNAPONLY=1; fi
      ;;
    v)
      VERBOSE=1
      ;;
    h)
      usage
      ;;
  esac
done


while read xuuid
do

  zoneuid=$xuuid

  if [ $VERBOSE -eq 1 ]; then echo - UUID $zoneuid - `vmadm list -p -o alias uuid=$xuuid`; fi

  ###

  zfs_filesystem=`vmadm get $zoneuid | json zfs_filesystem`

  if [ $SNAPONLY -ne 1 ]; then echo $zfs_filesystem; fi

  if [ $SNAPSHOT -eq 1 ]; then zfs list -r -H -t snapshot -o name $zfs_filesystem; fi

  ###

  while read disk
  do

    if [ $SNAPONLY -ne 1 ]; then echo $disk; fi

    if [ $SNAPSHOT -eq 1 ]; then zfs list -r -H -t snapshot -o name $disk; fi

  done < <(vmadm get $zoneuid | json disks | grep zfs_filesystem | awk -F"\"" '{print $4}')

  ###

  while read dataset
  do

    if [ $SNAPONLY -ne 1 ]; then echo $dataset; fi

    if [ $SNAPSHOT -eq 1 ]; then zfs list -r -H -t snapshot -o name $dataset; fi

  done < <(vmadm get $zoneuid | json datasets | json -a)

  if [ $VERBOSE -eq 1 ]; then echo " "; fi

done < <(vmadm list -p -o uuid)
