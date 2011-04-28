#! /bin/sh
### BEGIN INIT INFO
# Provides:          voyage-util
# Short-Description: Voyage Init script
# Required-Start:    $all
# Required-Stop:     $all
# Should-Start:      
# Should-Stop:       
# Default-Start:     2 3 4 5 
# Default-Stop:      0 1 6
### END INIT INFO
#
# skeleton  example file to build /etc/init.d/ scripts.
#       This file should be used to construct scripts for /etc/init.d.
#
#       Written by Miquel van Smoorenburg <miquels@cistron.nl>.
#       Modified for Debian
#       by Ian Murdock <imurdock@gnu.ai.mit.edu>.
#
# Version:  @(#)skeleton  1.9  26-Feb-2001  miquels@cistron.nl
#

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
#DAEMON=/usr/sbin/voyage-util
NAME=voyage-util
DESC=voyage-util

#test -x $DAEMON || exit 0

# Include voyage-util defaults if available
if [ -f /etc/default/voyage-util ] ; then
    . /etc/default/voyage-util
fi

start_leds()
{
	if [ $VOYAGE_LEDS = "NO" ] ; then return ; fi
	
	if [ ! -f /etc/voyage.conf ] ; then return ; fi
	. /etc/voyage.conf
	
	case $VOYAGE_PROFILE in
		'WRAP')
            echo heartbeat > /sys/class/leds/wrap\::power/trigger
            echo ide-disk > /sys/class/leds/wrap\::error/trigger
            echo netdev > /sys/class/leds/wrap\:\:extra/trigger
            echo eth0 > /sys/class/leds/wrap\:\:extra/device_name
            echo "link tx rx" > /sys/class/leds/wrap\:\:extra/mode			
			;;
		'ALIX')
			echo heartbeat > /sys/class/leds/alix\:1/trigger
			echo none > /sys/class/leds/alix\:2/trigger
			echo none > /sys/class/leds/alix\:3/trigger
			;;
		*)
			;;
	esac
}

set -e

case $1 in
	'start')
		if [ -f /voyage.1st ] ; then
				echo "First-time installation "
				echo -n "Re-generating host ssh keys ... "
				rm -f /etc/ssh/ssh_host_rsa_key
				ssh-keygen -q -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' || { echo "Fatal Error: Failed to generate RSA keypair" >&2; exit; }
				rm -f /etc/ssh/ssh_host_dsa_key
				ssh-keygen -q -t dsa -f /etc/ssh/ssh_host_dsa_key -N '' || { echo "Fatal Error: Failed to generate DSA keypair" >&2; exit; }

				#depmod -ae
				depmod -a
				
				rm -f /voyage.1st
				echo "Done."		
		fi
		
		echo -n "Removing /etc/nologin ... "
		/etc/init.d/rmnologin start
		echo "Done."
		start_leds
		;;
	'stop')

		;;
	force-reload|restart)

    	;;
	status)
	
		;;
	*)
	    ;;
esac

