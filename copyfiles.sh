#!/bin/bash
########################################################################
# Copy files from the Voyage Linux Distribution over to the user's     #
# target system.  This script is normally executed from the script     #
# 'voyage-install.sh', which previously sets up all of the various     #
# environment variables.  These (required) variables are:              #
#  RUNDIR       The directory from which voyage.update was called      #
#  EXECDIR      The directory containing the installation scripts      #
#  TARGET_DISK  The device onto which Voyage Linux is installed        #
#  TARGET_PART  The partition on TARGET_DISK for Voyage Linux          #
#  TARGET_MOUNT The mountpoint for the target disk                     #
#  BOOTSTRAP_PART If grub, which partition to use                      #
#  SYSTEM_BOOTSTRAP Which bootstrap loader to use (grub or lilo)       #
##                                                                     #
# Additionally, the following variables contain data from the file     #
# /etc/voyage.conf:                                                    #
#  VOYAGE_SYSTEM_CONSOLE   system console is 'standard' or 'serial'    #
#  VOYAGE_SYSTEM_SPEED     if serial, the baud rate                    #
#  VOYAGE_SYSTEM_PCMCIA    if pcmcia is enabled "yes/no"               #
#  VOYAGE_SYSTEM_MODULES   the module appended to /etc/modules         #
#                                                                      #
########################################################################

###############################################################
#    Mainline code starts here                                #
##############################################################

if [ ! "${HAVESCRIPTUTILS:+present}" ]; then
	echo "This script must be run under voyage.update" >&2
	exit
fi

source $EXECDIR/update-config.sh

# We assume that none of the target files are currently mounted.  Just to
# make sure, we check and force the user to restart if this isn't true.
exitflag=0
mp=`mount | grep $TARGET_DISK$TARGET_PART`
if [ $? -eq 0 ]; then
	mp=`echo $mp | sed -e "s/ type .*//;s/ on / is mounted on /"`
	err_msg "$mp - please unmount it!"
	exitflag=1
fi
if [ "$BOOTSTRAP" == "grub" ]; then
	mp=`mount | grep $TARGET_DISK$BOOTSTRAP_PART`
	if [ $? -eq 0 ]; then
		mp=`echo $mp | sed -e "s/ type .*//;s/ on / is mounted on /"`
		err_msg "$mp - please unmount it!"
		exitflag=1
	fi
fi
if [ $exitflag -ne 0 ]; then
	err_msg "Aborting copy request"
	exit
fi
# All looks ok - we can now mount the target directory
mount -t ext3 $TARGET_DISK$TARGET_PART $TARGET_MOUNT || \
  err_quit "Failed to mount $TARGET_DISK$TARGET_PART on $TARGET_MOUNT as an ext3 partition"

# Mount Ok - Parition correct now set ext2 label to ROOT_FS
e2label $TARGET_DISK$TARGET_PART ROOT_FS

# We are going to use rsync to copy files from the distribution to the
# target.  In order to minimise any flash writing, we first figure out
# any files which we don't want to copy.  First, we check if there is a
# file 'exclude-files' (which can contain a list of regular-expressions
# describing files)
if [ "$DISTDIR" = "/" ]; then 
	DISTDIRPREFIX="";
else 
	DISTDIRPREFIX="$DISTDIR";
fi

exclude="--exclude /tmp/cf --exclude '$DISTDIRPREFIX/sys/*' --exclude '$DISTDIRPREFIX/dev/*' --exclude '$DISTDIRPREFIX/proc/*'"
if [ -f $EXECDIR/exclude-files ]; then
	excl="$exclude --exclude-from=$EXECDIR/exclude-files"
else
	excl="$exclude"
fi

# Here we can generate a list (based upon the specified profile) of any
# files which are not needed
#               *** to be added later ***

# Ready to do the copy - it might take awhile, so output a message to let
# the user know what we are doing
echo -ne "Copying files .... " >&2
eval rsync -aHx --delete $excl $DISTDIRPREFIX/* $TARGET_MOUNT || \
  err_quit "Failed to copy files!"
echo -e "done\n" >&2

update_modules "$TARGET_MOUNT"
update_inittab "$DISTDIR" "$TARGET_MOUNT"
update_pcmcia "$TARGET_MOUNT"
remove_dnsmasq_pxe "$TARGET_MOUNT"
reconfig_resolvconf "$TARGET_MOUNT"
reconfig_ntp "$TARGET_MOUNT"
${EXECDIR}/setboot.sh
write_config "$TARGET_MOUNT/etc/voyage.conf" "$VOYAGE_CONF_LIST"
#umount $TARGET_MOUNT
echo "copyfiles.sh script completed" >&2
