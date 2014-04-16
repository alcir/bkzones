#!/bin/bash

perl="/usr/perl5/bin/perl"

outputfile="/tmp/todelete"

echo -n "" > $outputfile

usage() {
  echo "usage ./listoldest.sh -d <NUMBER OF DAYS TO KEEP> [-h]"
  exit 1
}

while getopts ":d:th" opt; do
  case $opt in
    d)
      DAYS=$OPTARG
      ;;
    t)
      TEST=1
      ;;
    h)
      usage
      ;;
  esac
done

if [[ -z "$DAYS" ]]
then
     usage
     exit 1
fi

#if [ $TEST -eq 1 ]
#then
#  echo Test mode: operations will not be performed
#fi

#TODAYTIMESTAMP=`$perl -e 'use POSIX qw(strftime); print strftime "%s",localtime(time());'`

TODAY=`$perl -e 'use POSIX qw(strftime); print strftime "%Y%m%d",localtime(time());'`

TODAYTIMESTAMP=`$perl -e 'use POSIX qw(strftime); 
   use Time::Local; 
   use Time::Piece; 
   my $t = Time::Piece->strptime("'$TODAY'","%Y%m%d");
   print $t->epoch; ';`

let DAYSTOSECONDS=$DAYS*86400

let OLDESTTIMESTAMP=$TODAYTIMESTAMP-$DAYSTOSECONDS

TIMESTAMPTODATE=`$perl -e 'use POSIX qw(strftime); print strftime "%Y%m%d",localtime('$OLDESTTIMESTAMP');'`

echo "Today $TODAY - timestamp $TODAYTIMESTAMP"
echo "Oldest $TIMESTAMPTODATE - timestamp $OLDESTTIMESTAMP"
echo ---
echo "Creating list of snapshots older than $DAYS days ($DAYSTOSECONDS seconds), that is before $TIMESTAMPTODATE"
echo ---

count=0
counttodel=0

while read line
do

       # echo $line
	
	let count=$count+1	

	ZFSDATE=`echo $line | awk -F"@" '{ print $2 }'`

	ZFSTIMESTAMP=`$perl -e 'use POSIX qw(strftime); 
           use Time::Local; 
           use Time::Piece; 
           my $t = Time::Piece->strptime("'$ZFSDATE'","%Y%m%d");
           print $t->epoch; '`

	if [ $ZFSTIMESTAMP -lt $OLDESTTIMESTAMP ]
	then

		let counttodel=$counttodel+1

		TIMESTAMPTODATE2=`$perl -e 'use POSIX qw(strftime); print strftime "%Y%m%d",localtime('$ZFSTIMESTAMP');'`
		echo "$ZFSTIMESTAMP ($TIMESTAMPTODATE2) less than $OLDESTTIMESTAMP ($TIMESTAMPTODATE)"
		echo $line marked to be deleted
		echo $line >> $outputfile
	fi

done < <(zfs list -t snapshot -o name | grep "zones/backup/")

echo ---
echo "File created: $outputfile"
echo "Scanned snapshots: $count"
echo "Snapshots to delete: $counttodel"
echo ---
echo ---

