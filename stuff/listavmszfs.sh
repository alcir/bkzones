#!/bin/bash

server="gz1.mydomain.com
gz2.mydomain.com
gz3.mydomain.com
"

if [ $# -gt 0 ]
then

	if [ "$1" == "-t" ]
	then
		printf %s "$server" | while IFS= read -r line
		do

			ssh $line "/opt/custom/bk/listallvmzfs.sh" </dev/null | awk -F":" '{print $1}'

		done
	
	else

		print "usage: listavms.sh [-t]"

	fi


else

printf %s "$server" | while IFS= read -r line
do

   echo $line
   ssh $line /opt/custom/bk/listallvmzfs.sh < /dev/null
   echo -e "--------------------\n"

done

fi
