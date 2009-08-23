#!/bin/bash
#
#	This is the main shell script for adjusting the configuration
#	of a 'live' Voyage Linux system
#

if [ ! "${HAVESCRIPTUTILS:+present}" ]; then
	echo "This script must be run under voyage.update" >&2
	exit
fi

#if [ $UID -ne 0 ]; then
#	err_quit "This script may only be run under the 'root' user!"
#fi

# Since we execute some other scripts, we must assure env vars are exported
set -a

# For live distribution, we should confirm that the basic root filesystem
# is sane.  For testing, I'm going to allow the target directory to be
# specified by the user
BASEDIR="/"
if [ ! -f $BASEDIR/etc/voyage.conf ]; then
	ask_work_dir "$BASEDIR" "install"
	BASEDIR=$w
fi

# this is redundant, but very good for development testing!!
if [ ! -f $BASEDIR/etc/voyage.conf ]; then
	err_quit "Logic error - can't find voyage.conf"
fi

# Initialise the configuration from voyage.conf
read_config "$BASEDIR/etc/voyage.conf" VOYAGE_CONF_LIST

# here we define the different choices which can be made by the user
OPTIONS="Change target directory%Select target profile%Set serial speed%Update all settings%Exit"

while true
do
	ask_setting "What would you like to do?" "$OPTIONS" 1

	case $v in
		1) ask_work_dir $BASEDIR "install";
		   BASEDIR=$w;;
		2) select-profile $BASEDIR;
		   if [ -z $w ]; then
		   	err_msg "Check Target Directory setting!\n\n";
		   fi;;
		3) $EXECDIR/setspeed.sh;;
		4) $EXECDIR/do-update.sh;;
		5) break;;
		*) err_quit "Invalid return code from ask_setting";;
	esac
done

