#!/bin/bash

# This scripts is called hourly by cron.

# Potentially dangerous operation.
# If you know what you're doing, uncomment the lines below.

#get_free_bytes() {
#    DF=`df --sync / 2> /dev/null | tail -n 1`
#    if [ `expr index "$DF" dev` == 0 ]; then
#        #Take the third argument.
#        FREEBYTES=`echo $DF | awk '{print $3}'`
#    else
#        #Take the fourth argument.
#        FREEBYTES=`echo $DF | awk '{print $4}'`
#    fi
#}
#
#get_free_bytes
#
#if [ $FREEBYTES -lt 50000 ]; then
#    while true; do
#        rm `ls -1 /var/log/bluetracker/scan.log.*`
#        get_free_bytes
#        if [ $FREEBYTES -gt 500000 ]; then
#            exit 0
#        fi
#    done
#fi
