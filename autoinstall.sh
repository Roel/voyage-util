#!/bin/bash
########################################################################

# by default export all variables
set -a

# remember the current dir for future use and get the path to
# the directory where this script is located
RUNDIR=$PWD
cd `dirname $0`
EXECDIR=$PWD
cd $RUNDIR

# load the script containing our utility routines
source $EXECDIR/script-utils.sh
# select-profile is a separate script but usually needed
source $EXECDIR/select-profile.sh

DISTDIR=/tmp/root
TARGET_DISK="/dev/sda"
TARGET_PART=1 
TARGET_MOUNT="/tmp/cf" 
BOOTSTRAP_PART=1
BOOTSTRAP="grub" 
SYSTEM_BOOTSTRAP=$BOOTSTRAP

INSTALL_PROFILE=alix
if [ ! -z $1 ] ; then INSTALL_PROFILE=$1 ; fi

PROFILE_FILE=/etc/voyage-profiles/$INSTALL_PROFILE.pro
if [ ! -f $PROFILE_FILE ] ; then 
	echo "Install profile $PROFILE_FILE not found !"
	exit 1
fi
source $PROFILE_FILE

echo "########################################################################"
echo "  WARNING: Voyage UGent Auto-Install will start in 5 seconds.  It will "
echo "           erase your disk in $TARGET_DISK."
echo "########################################################################"
sleep 5
if [ $? != 0 ] ; then exit 1; fi

########################################################################

echo heartbeat > /sys/class/leds/alix\:1/trigger
echo heartbeat > /sys/class/leds/alix\:2/trigger
echo heartbeat > /sys/class/leds/alix\:3/trigger

if [ ! -d $DISTDIR ] ; then mkdir $DISTDIR ; fi
if [ ! -d $TARGET_MOUNT ] ; then mkdir $TARGET_MOUNT ; fi
umount $DISTDIR &> /dev/null
umount $TARGET_MOUNT &> /dev/null

SQFS=$(find / -name "filesystem.squashfs" | head -n1)
if [ ! -z $SQFS ] ; then
	mount -o loop $SQFS $DISTDIR
else
	echo "filesystem.squashfs not found! Abort. "
	exit 1
fi

cd $DISTDIR

########################################################################

mount -t auto $TARGET_DISK$TARGET_PART $TARGET_MOUNT
if [ -f $TARGET_MOUNT/etc/hostname ]; then
    cat $TARGET_MOUNT/etc/hostname > /tmp/target-hostname
else
    echo voyage > /tmp/target-hostname
fi
umount $TARGET_MOUNT

########################################################################

$EXECDIR/format-cf.sh  $TARGET_DISK   << EOF

EOF

########################################################################

show_details

########################################################################

save_config_var VOYAGE_PROFILE VOYAGE_CONF_LIST
save_config_var SYSTEM_BOOTSTRAP VOYAGE_CONF_LIST
save_config_var VOYAGE_SYSTEM_SERIAL VOYAGE_CONF_LIST
save_config_var VOYAGE_SYSTEM_CONSOLE VOYAGE_CONF_LIST

########################################################################

$EXECDIR/copyfiles.sh
cat /tmp/target-hostname > $TARGET_MOUNT/etc/hostname
umount $TARGET_MOUNT

########################################################################

cd $RUNDIR
umount $DISTDIR

/etc/init.d/ntp stop
ntpdate 192.168.1.200
while [ $? -gt 0 ]; do
    sleep 10
    ntpdate 192.168.1.200
done

echo "########################################################################"
echo "  Voyage UGent Auto-Install complete. The system will halt in 5 secs."
echo "########################################################################"
sleep 5
if [ $? != 0 ] ; then exit 1; fi
halt
