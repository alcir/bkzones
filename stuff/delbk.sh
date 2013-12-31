#!/bin/bash

TEST=0

usage() {
  echo usage ./delbk.sh -f fileconlistauuiddacancellare [-t] [-h]
  exit 1
}

while getopts ":f:th" opt; do
  case $opt in
    f)
      file=$OPTARG
      ;;
    t)
      TEST=1
      ;;
    h)
      usage
      ;;
  esac
done

if [[ -z $file ]] 
then
     usage
     exit 1
fi

if [ $TEST -eq 1 ]
then
  echo Test mode: operations will not be performed
fi


while read line
do


line=`echo $line | sed 's/zones\///g'`

zfs get name zones/backup/$line &>/dev/null
EL=$?

if [ $EL -eq 0 ]
then

  echo zfs destroy -r zones/backup/$line
  
  if [ $TEST -eq 0 ]
  then
     zfs destroy -r zones/backup/$line
  fi

else

  echo zfs zones/backup/$line not here, ignoring

fi

done < <(cat $file)
