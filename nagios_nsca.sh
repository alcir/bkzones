#!/bin/bash

DIRECTORY=$(cd `dirname $0` && pwd)

#####

HOST_NAME=circe
SVC_DESCRIPTION=bkzones

NSCA_HOST=steno.pi.fgm
NSCA_PORT=5667
NSCA_CONF=$DIRECTORY/nsca/send_nsca.cfg
NSCA_EXE=$DIRECTORY/nsca/send_nsca

#####

RETURN_CODE=$1
PLUGIN_OUTPUT=$2

export LD_LIBRARY_PATH=$DIRECTORY/nsca

echo "$HOST_NAME;$SVC_DESCRIPTION;$RETURN_CODE;$PLUGIN_OUTPUT" | $NSCA_EXE -H $NSCA_HOST -p $NSCA_PORT -d ";" -c $NSCA_CONF
