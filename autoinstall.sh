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
TARGET_DISK="/dev/hda"
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
echo "           erase your disk in $TARGET_DISK.  If you want to stop, please"
echo "           press Ctrl+C now !!"
echo "########################################################################"
sleep 5
if [ $? != 0 ] ; then exit 1; fi

########################################################################

if [ ! -d $DISTDIR ] ; then mkdir $DISTDIR ; fi
if [ ! -d $TARGET_MOUNT ] ; then mkdir $TARGET_MOUNT ; fi
umount $DISTDIR > /dev/null
umount $TARGET_MOUNT > /dev/null

SQFS=$(find / -name "filesystem.squashfs" | head -n1)
if [ ! -z $SQFS ] ; then
	mount -o loop $SQFS $DISTDIR
else
	echo "filesystem.squashfs not found! Abort. "
	exit 1
fi

cd $DISTDIR

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

########################################################################

cd $RUNDIR
umount $DISTDIR

echo "########################################################################"
echo "  Voyage UGent Auto-Install complete. The system will halt in 5 secs."
echo "  If you want to stop, please press Ctrl+C now !!"
echo "########################################################################"
sleep 5
if [ $? != 0 ] ; then exit 1; fi
halt
