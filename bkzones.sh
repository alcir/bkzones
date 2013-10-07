#!/bin/bash

# Ver 0.0.10


#
# Var
#

workdir=$(cd `dirname $0` && pwd)

. $workdir/bkzones.conf

#bkdestserver="iperione.hypervisor.pi.fgm"
#bkdestdir="/zones/backup/indici_e_conf"
#bkdestdirxml="$bkdestdir/xml/`hostname`/"
#bkdestdirindex="$bkdestdir/index/`hostname`/"
#excludedlist="$workdir/excluded"
#sshparam="root@$bkdestserver"
#destinationpool="zones/backup"

bkdestdirxml="$bkdestdirxml/`hostname`/"
bkdestdirindex="$bkdestdirindex/`hostname`/"

TODAY=`date +%Y%m%d`
#YESTERDAY=`perl -e 'use POSIX qw(strftime); print strftime "%Y%m%d",localtime(time()- 3600*24);'`
YESTERDAY=`TZ=GMT+24 date +%Y%m%d`;

logfile=$logdir/$TODAY.log

if [ ! -d "$logdir" ]; then
  mkdir $logdir
fi

NAGIOS=0

while getopts ":o:y:t:nvh" opt; do
  case $opt in
    o)
      ONLYFILE=$OPTARG
      ;;
    n)
      NAGIOS=1
      ;;
    t)
      TODAY=$OPTARG
      ;;
    y)
      YESTERDAY=$OPTARG
      ;;
    v)
      _V=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit
      ;;
  esac
done

echo $ONLYFILE

#
# Functions
#

#function log () {
#
#    if [[ $_V -eq 1 ]]; then
#        echo -e "$@"
#    fi
#
#    echo -e "$@" >> $logfile
#
#}

function log()
{
   if [ "$1" ]
   then
      data="$1"
      echo "[$(date +"%D %T")] $data">> $logfile
      if [[ $_V -eq 1 ]]; then
         #echo "[$(date +"%D %T")] $data" 
	 echo "$data"
      fi

   else
      while IFS='' read -r data
      do
         echo "[$(date +"%D %T")] $data" >> $logfile
         if [[ $_V -eq 1 ]]; then
            #echo "[$(date +"%D %T")] $data"
            echo "$data"
         fi
      done
   fi
}


alreadyexists() {
  if zfs list -H -o name -t snapshot | sort | grep "$1" > /dev/null
  then
    return 0
  else
    return 1
  fi
}

#descendent() {
##  number=`zfs list -rH $1 | wc -l | tr -d ' '`
##  echo $number
##  if [ $number -ne 1 ]
##  then
##    return 1
##  else
##    return 0
##  fi
##  log "Check descendent" 
##  log "zfs list -rH $2 | grep $1"
#  zfs list -rH $2 | grep $1 > /dev/null  
#  EL=$?
#  if [ $EL -eq 0 ]
#  then
##    log "$1 is a descendent dataset of $2"
#    return 0
#  else
##    log "$1 is NOT a descendent dataset of $2"
#    return 1
#  fi
#}

remoteexists() {

  log "...Checking if it is the first time we zfs send to remote $1"
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

  log "...Checking if remote $zfs ($strip) exists"

  if remoteexists $destinationpool/$strip
  then

    log "...Maybe this is the first time transfer for $destinationpool/$strip"
    log "...Let's proceed with non incremental send"
    zfs send $zfs@$TODAY | ssh $sshparam zfs receive -v $destinationpool/$strip &> >(log)
    EL=$?

    if [ $EL -ne 0 ]
    then
       log "...zfs send problem: errorlevel $EL"
       return $EL
    fi

  else 

    log "...This is not the first send, going on"

    if zfs list -H -o name -t snapshot | sort | grep "$zfs@$YESTERDAY" > /dev/null; then
      log "...Yesterday snapshot, $zfs@$YESTERDAY, exists lets proceed with backup"
      zfs send -i $zfs@$YESTERDAY $zfs@$TODAY | ssh $sshparam zfs receive -Fv $destinationpool/$strip &> >(log)
      EL=$?

      if [ $EL -ne 0 ]
      then
         log "...Problem in zfs send: errorlevel $EL"
         return $EL
      fi
   
      log "...zfs backup completed, destroying yesterday snapshot $zfs@$YESTERDAY"
      zfs destroy $zfs@$YESTERDAY &> >(log)
      EL=$?

      if [ $EL -ne 0 ]
      then
         log "...zfs destroy problem: errorlevel $EL"
         return $EL
      fi
      
    else
  
      log "...Cannot proceed: missing yesterday snapshot $zfs@$YESTERDAY"
      return 100
  
    fi

  fi

}

backupzfs() {
  
  zoneuid=$1

  log "-backupzfs function called for zoneuid $zoneuid"

  log "+Get VM's zfs_filesystem"

  zfs_filesystem=`vmadm get $zoneuid | json zfs_filesystem`

  log ".Working on zfs_filesystem $zfs_filesystem"

  if alreadyexists $zfs_filesystem@$TODAY
  then

    log "..cannot proceed: zfs_filesystem snapshot, $zfs_filesystem@$TODAY already exists"
    return 101

  else

    log "..Taking today snapshot of $zfs_filesystem@$TODAY"
#    zfs snapshot -r $zfs_filesystem@$TODAY
    zfs snapshot $zfs_filesystem@$TODAY
    EL=$?
    if [ $EL -ne 0 ]
    then 
       log "..Today snapshot problem: errorlevel $EL"
       return $EL
    fi

    log "..Invoking zfssend for filesystem $zfs_filesystem"
    zfssend $zfs_filesystem
    EL=$?

    if [ $EL -ne 0 ]
    then 
       log "..zfssend function problem: errorlevel $EL"
       return $EL
    fi

  fi

  log "+Get VM's disks"

  count=0

#  vmadm get $zoneuid | json disks | grep zfs_filesystem|awk -F"\"" '{print $4}' | while read disk
  while read disk
  do

    let count=$count+1

    log ".Working on disk $disk"

    if alreadyexists $disk@$TODAY
    then

      log "..disk snapshot, $disk@$TODAY already exists"
      return 102

    else

      log "..Taking today snapshot of $disk@$TODAY"
      zfs snapshot -r $disk@$TODAY
      EL=$?

      if [ $EL -ne 0 ]
      then 
         log "..zfs snapshot problem: errorlevel $EL"
         return $EL
      fi

      log "..Invoking zfssend for disk $disk"
      zfssend $disk
      EL=$?

      if [ $EL -ne 0 ]
      then
         log "..zfssend function problem: errorlevel $EL"
         return $EL
      fi

    fi

  done < <(vmadm get $zoneuid | json disks | grep zfs_filesystem|awk -F"\"" '{print $4}')
#  done

  if [ $count -eq 0 ]
  then
     log "..no disks associated to this VM $count"
  fi

  log "+Get VM's datasets"

  count=0

#  vmadm get $zoneuid | json datasets | json -a | while read dataset
  while read dataset
  do

    let count=$count+1

    log "..Working on dataset $dataset"

#    if descendent $dataset $zfs_filesystem
#    then
#      log "..$dataset is a descendent, we already have a backup since we use zfs snapshot -r <zone_zfs>"
#      log "...let's move on"
#      continue
#    else
#      log "..$dataset is not a descendent dataset, let's move on"
#    fi

    if alreadyexists $dataset@$TODAY
    then
  
      log "..dataset snapshot, $dataset@$TODAY already exists"
      return 103
  
    else

      log "..Taking today snapshot of $dataset@$TODAY"
      zfs snapshot -r $dataset@$TODAY
      EL=$?

#      log "zfs snapshot -r $dataset@$TODAY errorlevel $EL"
#      if [ $EL -ne 0 ]; then log Problem; return $EL; fi

      if [ $EL -ne 0 ]
      then
         log "..zfs snapshot problem: errorlevel $EL"
         return $EL
      fi

      log "..Invoking zfssend for dataset $dataset"
      zfssend $dataset
      EL=$?

      if [ $EL -ne 0 ]
      then
         log "..zfs snapshot problem: errorlevel $EL"
         return $EL
      fi

    fi

  done < <(vmadm get $zoneuid | json datasets | json -a)

  if [ $count -eq 0 ]
  then
     log "..no datasets associated to this VM $count"
  fi 


  log "End backupzfs for $zoneuid"

}

#
# Start
#

log "Start `date`"

log "Today $TODAY Yesterday $YESTERDAY Nagios $NAGIOS"

log "Start rsync /etc/zones/index to $bkdestserver:$bkdestdirindex"

rsync -arp -e "ssh -i /root/.ssh/id_rsa" /etc/zones/index $bkdestserver:$bkdestdirindex 2> >(log)

EL=$?

log "End rsync index: errorlevel $EL"

if [ $EL -ne 0 ]
then 
  log "Problem rsync index $EL"
  FINALEL=1
else
  FINALEL=0
fi

log "-------"

if [ $FINALEL -eq 0 ]
then
  #vmadm list -p -o uuid | while read xuuid

  if [[ -z $ONLYFILE ]]
  then

    uuidtodo="vmadm list -p -o uuid"

  else

    if [ -f $ONLYFILE ]
    then
      uuidtodo="cat $ONLYFILE"
    else
      uuidtodo="cat /dev/null"
      MESSAGE="$ONLYFILE doesn't exist"
      let FINALEL=1
      log "$MESSAGE"
    fi

  fi

  while read xuuid
  do

    grep $xuuid $excludedlist 2>&1>/dev/null
    EL=$?
  
    if [ $EL -ne 0 ]
    then
  
      log "Working on VM $xuuid - `vmadm list -p -o alias uuid=$xuuid`"

      log "Start rsync VM xml to $bkdestserver:$bkdestdirxml"

      rsync -arp -e "ssh -i /root/.ssh/id_rsa" /etc/zones/$xuuid.xml $bkdestserver:$bkdestdirxml &> >(log)
      EL=$?

      log "End rsync VM xml errorlevel $EL"

      if [ $EL -ne 0 ]
      then
         log "Problem rsync index $EL"
         let FINALEL=1
      fi

      log "Now working on zone's zfs (backupzfs)"

      backupzfs $xuuid
      EL=$?

      log "End zone bk: errorlevel $EL"

      if [ $EL -ne 0 ]
      then
        let FINALEL=1
      fi

    else

      log "Ignoring $xuuid excluded"

    fi

    log "-------"

  done < <($uuidtodo)
fi

if [ $FINALEL -ne 0 ]
then

   MESSAGE="There were problems in one or more operations, see logfile $logfile"

   log "$MESSAGE"

else

   MESSAGE="No errors reported"

   log "$MESSAGE"

fi

if [ $NAGIOS -eq 1 ]
then

   log "Invoking Nagios NSCA"

   log "`$workdir/nagios_nsca.sh $FINALEL "$MESSAGE"`"

fi

log "End script `date`"
