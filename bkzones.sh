#!/bin/bash

# Ver 0.0.2

#
# Var
#

workdir="/opt/custom/bk"
bkdestserver="yourbackup.server.host"

bkdestdir="/zones/backup/indexes_and_conf"
bkdestdirxml="$bkdestdir/xml/`hostname`/"
bkdestdirindex="$bkdestdir/index/`hostname`/"

excludedlist="$workdir/excluded"

sshparam="root@$bkdestserver"

destinationpool="zones/backup"

TODAY=`date +%Y%m%d`
#YESTERDAY=`perl -e 'use POSIX qw(strftime); print strftime "%Y%m%d",localtime(time()- 3600*24);'`
YESTERDAY=`TZ=GMT+24 date +%Y%m%d`;

YESTERDAY=$1
TODAY=$2


#
# Functions
#

pacco() {
echo ooo
}

cane() {
 pacco
 EL=$?
 return $EL
}

alreadyexists() {
  if zfs list -H -o name -t snapshot | sort | grep "$1" > /dev/null
  then
    return 0
  else
    return 1
  fi
  
}

remoteexists() {

  echo -e "Checking if it is the first time we zfs send to remote $1"
  ssh $sshparam zfs list $1 </dev/null &>/dev/null
  EL=$?

  if [ $EL -eq 0 ]
  then 
    return 1
  else
    return 0
  fi

}

#ifel() {
#  if [ $1 -ne 0 ]
#  then
#    echo $1 ifel ret false
#    var=false
#  else
#    echo $1 ifel ret true
#    var=true
#  fi
#}

zfssend() {

  zfs=$1
  strip=`echo $zfs | sed 's/^zones\///g'`

  echo -e "Checking if remote $zfs ($strip) exists"

  if remoteexists $destinationpool/$strip
  then

    echo "Maybe this is the first time transfer for $destinationpool/$strip"
    echo "Let's proceed with non incremental send"

    zfs send $zfs@$TODAY | ssh $sshparam zfs receive -v $destinationpool/$strip
    EL=$?
    if [ $EL -ne 0 ]; then echo Problem; return $EL; fi

  else 

    echo "This is not the first send, going on"

    if zfs list -H -o name -t snapshot | sort | grep "$zfs@$YESTERDAY" > /dev/null; then
      echo "Yesterday snapshot, $zfs@$YESTERDAY, exists lets proceed with backup"
  
      zfs send -i $zfs@$YESTERDAY $zfs@$TODAY | ssh $sshparam zfs receive -Fv $destinationpool/$strip
      EL=$?
      if [ $EL -ne 0 ]; then echo Problem; return $EL; fi
   
      echo "Backup completed, destroying yesterday snapshot"
      zfs destroy -r $zfs@$YESTERDAY
      EL=$?
      if [ $EL -ne 0 ]; then echo Problem; return $EL; fi
      
    else
  
      echo "Missing yesterday snapshot $zfs@$YESTERDAY"
      return 100
  
    fi

  fi

}

backupzfs() {
  
  zoneuid=$1

  echo -e "backupzfs called for zoneuid $zoneuid\n"

  echo -e "\nGet zfs_filesystem"

  zfs_filesystem=`vmadm get $zoneuid | json zfs_filesystem`

  echo -e "\nWorking on zfs_filesystem $zfs_filesystem"

  if alreadyexists $zfs_filesystem@$TODAY
  then

    echo "zfs_filesystem snapshot, $zfs_filesystem@$TODAY already exists"
    return 101

  else

    echo "Taking today snapshot of $zfs_filesystem@$TODAY"
    zfs snapshot -r $zfs_filesystem@$TODAY
    EL=$?
    if [ $EL -ne 0 ]; then echo Problem; return $EL; fi

    echo ". zfssend $zfs_filesystem"
    zfssend $zfs_filesystem
    EL=$?
    if [ $EL -ne 0 ]; then echo Problem; return $EL; fi

  fi

  echo -e "\nGet disks"

  vmadm get $zoneuid | json disks | grep zfs_filesystem|awk -F"\"" '{print $4}' | while read disk
  do

    echo -e "\nWorking on disk $disk"

    if alreadyexists $disk@$TODAY
    then

      echo "disk snapshot, $disk@$TODAY already exists"
      return 102

    else

      echo "Taking today snapshot of $disk@$TODAY"
      zfs snapshot -r $disk@$TODAY
      EL=$?
      if [ $EL -ne 0 ]; then echo Problem; return $EL; fi

      echo ".. zfssend $disk"
      zfssend $disk
      EL=$?
      if [ $EL -ne 0 ]; then echo Problem; return $EL; fi

    fi

  done

  echo -e "\nGet datasets"

  vmadm get $zoneuid | json datasets | json -a | while read dataset
  do

    echo -e "\nWorking on dataset $dataset"

    if alreadyexists $dataset@$TODAY
    then
  
      echo "dataset snapshot, $dataset@$TODAY already exists"
      return 103
  
    else

      echo "Taking today snapshot of $dataset@$TODAY"
      zfs snapshot -r $dataset@$TODAY
      EL=$?
      echo "zfs snapshot -r $dataset@$TODAY errorlevel $EL"
      if [ $EL -ne 0 ]; then echo Problem; return $EL; fi

      echo "... zfssend $dataset"
      zfssend $dataset
      EL=$?
      echo "zfssend $dataset errorlevel $EL"
      if [ $EL -ne 0 ]; then echo Problem; return $EL; fi

    fi

  done

  echo -e "\n- End backupzfs for $zoneuid\n\n"

}

#
# Start
#

echo rsync /etc/zones/index

rsync -arp -e "ssh -i /root/.ssh/id_rsa" /etc/zones/index $bkdestserver:$bkdestdirindex
EL=$?

echo errorlevel $EL

echo -e "-------\n\n"

FINALEL=0

#vmadm list -p -o uuid | while read xuuid
while read xuuid
do

  grep $xuuid $excludedlist 2>&1>/dev/null
  EL=$?

  if [ $EL -ne 0 ]
  then

    echo -e "Working on $xuuid - `vmadm list -p -o alias uuid=$xuuid`\n"

    echo rsync xml

    rsync -arp -e "ssh -i /root/.ssh/id_rsa" /etc/zones/$xuuid.xml $bkdestserver:$bkdestdirxml
    EL=$?

    echo errorlevel $EL

    echo -e "\n+ Now working on zone's zfs"

    backupzfs $xuuid
    ELLL=$?

    echo "End. Errorlevel $ELLL"

    if [ $ELLL -ne 0 ]
    then
      let FINALEL=1
    fi

  else

    echo $xuuid excluded

  fi

  echo -e "\n--------\n\n"

done < <(vmadm list -p -o uuid)

if [ $FINALEL -ne 0 ]
then

   echo -e "\nThere were problems in one or more operations\n"

else

   echo -e "\nNo error reported\n"
fi
