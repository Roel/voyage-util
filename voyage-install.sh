#!/bin/bash
#
#	This is the main shell script for creating a new Voyage Linux
#	disk from the distribution files
#


if [ ! "${HAVESCRIPTUTILS:+present}" ]; then
        echo "This script must be run under voyage.update" >&2
        exit
fi
		
# Since we execute some other scripts, we must assure env vars are exported
set -a

CONFIGFILE=.voyage-install.conf

update_hostname() {
    local a
    while true
    do
        read_response "Please specify the hostname of the installed system: " a
        if [ "$a" != "" ]; then
            echo "$a" > $TARGET_MOUNT/etc/hostname
            umount $TARGET_MOUNT
            break
        fi
    done
}

#
#	Function select_target_disk
#	Sets the environment variables TARGET_DISK, TARGET_PART
#	and TARGET_MOUNT
#
select_target_disk() {
	local a
	if [ "$TARGET_PART" == "" ]; then
		TARGET_PART=1
	fi
	
	#print a partition info
	if [ -f /proc/partitions ] ; then
		echo "Partitions information"
		cat /proc/partitions
		echo
	fi
	
	while true
	do
		read_response "Which device accesses the target disk [$TARGET_DISK]? " a
		a=${a:-$TARGET_DISK}
		if [ ! -b $a ]; then
			err_msg "$a is not a disk device!"
			continue
		fi
		if [ "${a%%[!0-9]}" == "$a" ]; then
# extra stuff for testing with loop device - needs to be removed!		
#			err_msg "$a must not include a unit number"
#			continue
			a=${a%%[0-9]}
		fi
		TARGET_DISK=$a
#		break
#	done
#	while true
#	do
		read_response "Which partition should I use on $TARGET_DISK for the Voyage system [$TARGET_PART]? " a
		a=${a:-$TARGET_PART}
		if [ ! -b $TARGET_DISK$a ]; then
			err_msg "$TARGET_DISK$a is not a disk device!"
			continue
		fi
		TARGET_PART=$a
		break
	done
	
	#print a device info
	if [ -f /lib/udev/vol_id ] ; then
		echo "Device information for $TARGET_DISK$a"
		echo "    Type  = $(/lib/udev/vol_id -t $TARGET_DISK$a)"
		echo "    Label = $(/lib/udev/vol_id -l $TARGET_DISK$a)"
		echo "    UUID  = $(/lib/udev/vol_id -u $TARGET_DISK$a)"
		echo ""
	fi
	
	
	if [ -d /tmp/cf ] ; then TARGET_MOUNT="/tmp/cf" ; fi
	while true
	do
		read_response "Where can I mount the target disk [$TARGET_MOUNT]? " a
		a=${a:-$TARGET_MOUNT}
		if [ ! -d $a ]; then
			err_msg "$a is not a directory!"
			continue
		fi
		TARGET_MOUNT=$a
		break
	done
	# Assure data is stored for next run
	save_config_var TARGET_DISK CONFIGLIST
	save_config_var TARGET_PART CONFIGLIST
	save_config_var TARGET_MOUNT CONFIGLIST
}

#
#	Function select_target_boot()
#	Selects which bootstrap loader to us
#	Sets the environment variable SYSTEM_BOOTSTRAP
#	with the result
#
select_target_boot() {
	local a
	while true
	do
		read_response "Which loader do you want (grub or lilo) [$SYSTEM_BOOTSTRAP]? " a
		a=${a:-$SYSTEM_BOOTSTRAP}
		if [ "$a" != "grub" -a "$a" != "lilo" ]; then
			err_msg "Invalid response '$a' - must be 'grub' or 'lilo'"
			continue
		fi
		SYSTEM_BOOTSTRAP=$a
		break
	done
	if [ $SYSTEM_BOOTSTRAP == "grub" ]; then
		while true
		do
			read_response "Which partition is used for bootstrap [$BOOTSTRAP_PART]? " a
			a=${a:-$BOOTSTRAP_PART}
			if [ $a -lt 1 -o $a -gt 9 ]; then
				err_msg "Invalid response '$a' - try again"
				continue
			fi
			BOOTSTRAP_PART=$a
			save_config_var BOOTSTRAP_PART CONFIGLIST
			break
		done
	fi
	save_config_var SYSTEM_BOOTSTRAP VOYAGE_CONF_LIST
	save_config_var SYSTEM_BOOTSTRAP CONFIGLIST
}

#
#	Function select_target_console()
#	Selects serial terminal or console interface
#	If serial is chosen, also selects the baud rate
#	Sets environment vars VOYAGE_SYSTEM_CONSOLE and VOYAGE_SYSTEM_SERIAL
#
select_target_console() {
	if [ "$VOYAGE_SYSTEM_CONSOLE" == "standard" ]; then
		VOYAGE_SYSTEM_CONSOLE_DEFAULT=2
	else
		VOYAGE_SYSTEM_CONSOLE_DEFAULT=1
	fi
	local a opts="1:Serial Terminal:%2:Console Interface:"
	ask_setting "Select terminal type:" "$opts" $VOYAGE_SYSTEM_CONSOLE_DEFAULT
	case $v in
		1) VOYAGE_SYSTEM_CONSOLE="serial";;
		2) VOYAGE_SYSTEM_CONSOLE="standard";;
		*) err_quit "Unrecognized response from ask_setting";;
	esac
	if [ "$VOYAGE_SYSTEM_CONSOLE" == "serial" ]; then
		get_serial_speed $VOYAGE_SYSTEM_SERIAL
		save_config_var VOYAGE_SYSTEM_SERIAL VOYAGE_CONF_LIST
		save_config_var VOYAGE_SYSTEM_SERIAL CONFIGLIST
	fi
	save_config_var VOYAGE_SYSTEM_CONSOLE VOYAGE_CONF_LIST
	save_config_var VOYAGE_SYSTEM_CONSOLE CONFIGLIST
}

#
#	Function select_fs_creation()
#	Selects if we do partitioning create the file system
#	Sets the environment MAKEFS
#	with the result
#
select_fs_creation () {
	local MAKEFS_DEFAULT
	MAKEFS_DEFAULT="$MAKEFS"
	if [ "$MAKEFS" = "" ]; then 
		MAKEFS_DEFAULT=1
	fi

	local a opts="1:Partition Flash Media and Create Filesystem%2:Use Flash Media as-is"
	ask_setting "What shall I do with your Flash Media?" "$opts" "$MAKEFS_DEFAULT"
	case $v in
		1) MAKEFS=1;;
		2) MAKEFS=2;;
		*) err_quit "Unrecognized response from ask_setting";;
	esac
	save_config_var MAKEFS VOYAGE_CONF_LIST
	save_config_var MAKEFS CONFIGLIST
}

#
#	Function confirm_copy_details()
#	Checks that all required settings have been made before
#	starting copying the distribution data to the target.  If
#	any are missing, calls the appropriate function to obtain
#	the data.  Presents a summary of what is about to happen
#	for confirmation by the user, and in confirmed calls the
#	actual copy script.
#
confirm_copy_details() {
	if [ -z "$TARGET_DISK" -o -z "$TARGET_PART" -o -z "$TARGET_MOUNT" ]; then
		select_target_disk
	fi
	if [ -z "$SYSTEM_BOOTSTRAP" ]; then
		select_target_boot
	elif [ $SYSTEM_BOOTSTRAP != grub -a $SYSTEM_BOOTSTRAP != lilo ]; then
		select_target_boot
	fi
	
	if [ $SYSTEM_BOOTSTRAP == "grub" -a -z "$BOOTSTRAP_PART" ]; then
		BOOTSTRAP_PART=$TARGET_PART
		save_config_var BOOTSTRAP_PART CONFIGLIST
	fi
			
	if [ -z "$VOYAGE_SYSTEM_CONSOLE" ]; then
		select_target_console
	fi
	if [ -z "$VOYAGE_SYSTEM_SERIAL" -a "$VOYAGE_SYSTEM_CONSOLE" == "serial" ]; then
		select_target_console
	fi
	cat >&2 <<EOM
	
Configuration details:
----------------------

Distribution directory:   $DISTDIR

Disk/Flash Device:        $TARGET_DISK
Installation Partition:   $TARGET_DISK$TARGET_PART
EOM
	if [ $MAKEFS == 1 ]; then
		cat >&2 <<EOM
Create Partition and FS:  yes
EOM
	fi

	if [ $SYSTEM_BOOTSTRAP == "grub" ]; then
		cat >&2 <<EOM
Bootstrap Partition:      $TARGET_DISK$BOOTSTRAP_PART
EOM
	fi
	cat >&2 <<EOM

Will be mounted on:       $TARGET_MOUNT

Target system profile:    $VOYAGE_PROFILE
Target console:           $VOYAGE_SYSTEM_CONSOLE
EOM
	if [ $VOYAGE_SYSTEM_CONSOLE == "serial" ]; then
		cat >&2 <<EOM
Target baud rate:         $VOYAGE_SYSTEM_SERIAL
EOM
	fi
	cat >&2 <<EOM

Bootstrap installer:      $SYSTEM_BOOTSTRAP
EOM
	if [ $SYSTEM_BOOTSTRAP == grub ]; then
		cat >&2 <<EOM
Bootstrap partition:      $TARGET_DISK$BOOTSTRAP_PART
EOM
	fi

	if [ "$1" != "run" ]; then 
		read_response "\nOK to continue (y/n)? " a
		if [ "$a" == "Y" ]; then
			a="y"
		fi
		if [ "$a" != "y" ]; then
			return
		fi
	fi

	echo "Ready to go ...." >&2
	[ "$MAKEFS" = 1 ] && ${EXECDIR}/format-cf.sh -t $TARGET_DISK -b $BOOTSTRAP_PART -y
	${EXECDIR}/copyfiles.sh
}


############################################
#                                          #
#        Main script begins here           #
#                                          #
############################################

# Check if the user is running as 'root'.  If not, output a
# message and terminate the run
if [ $EUID -ne 0 ]; then
	cat >&2 <<EOM
*******************************************************
* You are not running this script as 'root'.  Various *
* commands  need  to be executed  which require  root *
* permissions.   Please  login as 'root'  and restart *
*******************************************************
EOM
	err_quit "Script can only be run by root"
fi

# This attempts to set the default values
#DISTDIR=`pwd`
VOYAGE_PROFILE=ALIX
TARGET_DISK=/dev/sde
TARGET_PART=1
TARGET_MOUNT=/tmp/cf
BOOTSTRAP_PART=1
SYSTEM_BOOTSTRAP=grub
SYSTEM_HOSTNAME=voyage
MAKEFS=""

VOYAGE_SYSTEM_SERIAL=38400
VOYAGE_SYSTEM_CONSOLE=serial

run_dialog=1

usage () {
	cat << EOF
usage: $0 [options]
		-i  install voyage linux  default=ask
		-u  update  voyage linux  default=ask
		-P  VOYAGE_PROFILE        default=$VOYAGE_PROFILE
		-t  TARGET_DISK           default=$TARGET_DISK
		-p  TARGET_PART           default=$TARGET_PART
		-m  TARGET_MOUNT          default=$TARGET_MOUNT
		-b  BOOTSTRAP_PART        default=$BOOTSTRAP_PART
		-g  SYSTEM_BOOTSTRAP=grub default=$SYSTEM_BOOTSTRAP
		-l  SYSTEM_BOOTSTRAP=lilo default=$SYSTEM_BOOTSTRAP
		-s  VOYAGE_SYSTEM_SERIAL  default=$VOYAGE_SYSTEM_SERIAL
		-c  VOYAGE_SYSTEM_CONSOLE default=$VOYAGE_SYSTEM_CONSOLE
		-h  SYSTEM_HOSTNAME       default=$SYSTEM_HOSTNAME
		-d  DISTDIR               default=$DISTDIR
		-f  partition and mkfs    default=ask
		-U  use flash media as-is default=ask
EOF
}

doopt () {
	# Variable usage:
	# x       actual command line element being evaluated
	# BITMAP  a bit vector to collect if all parameters are set
	# CLA_*   variables corresponding to teh configuration variables
	# 
	# output: $run_dialog $CLA_*

	local x
	local BITMAP
	BITMAP=0
	while [ $# -gt 0 ]; do
		x="$1"; shift
	
		case "$x" in
		-P) CLA_VOYAGE_PROFILE="$1"
			BITMAP=$[ $BITMAP | 1 ]
		    shift
			;;
		-t) CLA_TARGET_DISK="$1"
			BITMAP=$[ $BITMAP | 2 ]
		    shift
			;;
		-p) CLA_TARGET_PART="$1"
			BITMAP=$[ $BITMAP | 4 ]
		    shift
			;;
		-m) CLA_TARGET_MOUNT="$1"
			BITMAP=$[ $BITMAP | 8 ]
		    shift
			;;
		-b) CLA_BOOTSTRAP_PART="$1"
			BITMAP=$[ $BITMAP | 16 ]
		    shift
			;;
		-g) CLA_SYSTEM_BOOTSTRAP="grub"
			BITMAP=$[ $BITMAP | 32 ]
			;;
		-l) CLA_SYSTEM_BOOTSTRAP="lilo"
			BITMAP=$[ $BITMAP | 32 ]
			;;
		-s) CLA_VOYAGE_SYSTEM_SERIAL="$1"
			BITMAP=$[ $BITMAP | 64 ]
		    shift
			;;
		-c) CLA_VOYAGE_SYSTEM_CONSOLE="$1"
			BITMAP=$[ $BITMAP | 128 ]
		    shift
			;;
		-h) CLA_SYSTEM_HOSTNAME="$1"
			BITMAP=$[ $BITMAP | 256 ]
		    shift
			;;
		-d) CLA_DISTDIR="$1"
			BITMAP=$[ $BITMAP | 512 ]
		    shift
			;;
		-f) CLA_MAKEFS="1"
			BITMAP=$[ $BITMAP | 1024 ]
			;;
		-U) CLA_MAKEFS="2"
			BITMAP=$[ $BITMAP | 1024 ]
			;;
		*)  usage
			exit 1
			;;
		esac
	done
	if [ $BITMAP != 2047 ]; then
		echo "some mandatory options are unset, please enter them interactively"
		run_dialog=1
	else 
		run_dialog=0
	fi
}

doopt "$@"

# The logic here is a little confusing. First, we may or may not have
# a stored $CONFIGFILE [.voyage-install.conf] # which contains data
# saved from previous invocations.  If we do have it, we need to read
# it just to find out where to look for the distribution directory
# -- except for $CLA_DISTDIR being set by the command line option "-d"
# which would override any setting of $DISTDIR.  After that we will
# read in 'voyage.conf' from the distribution.  However, if on previous
# invocations the user has changed some of the profile settings, those
# changed settings will be lost.  To solve this, we will re-read the
# stored config after reading the distribution profile.
read_config "$CONFIGFILE" CONFIGLIST

if [ ! -z "$CLA_DISTDIR" ]; then
	DISTDIR="$CLA_DISTDIR"
else
	# Set the defaults in case there are no saved values
	if [ -z "$DISTDIR" ]; then
		ask_work_dir "$RUNDIR" "distribution"
		DISTDIR=$w
		save_config_var DISTDIR CONFIGLIST
	fi
fi
#	export DISTDIR

# Initialise the configuration from voyage.conf
if [ ! -f ${DISTDIR}/etc/voyage.conf ]; then
	err_quit "Logic error - can't find voyage.conf!"
fi
read_config "$DISTDIR/etc/voyage.conf" VOYAGE_CONF_LIST
# Then (possibly) override those settings with the $CONFIGFILE ones
read_config "$CONFIGFILE" CONFIGLIST

# This next test should never happen, but who knows :-)
if [ -z $VOYAGE_PROFILE ]; then
	VOYAGE_PROFILE=ALIX	# default is ALIX
	save_config_var VOYAGE_PROFILE VOYAGE_CONF_LIST
fi

# assure the profile is saved in the user's saved defaults
save_config_var VOYAGE_PROFILE CONFIGLIST

# command line parameters are not supposed to overwrite the config 
# file on disk. so they go here
[ ! -z "$CLA_VOYAGE_PROFILE"        ] && VOYAGE_PROFILE="$CLA_VOYAGE_PROFILE"               
[ ! -z "$CLA_TARGET_DISK"           ] && TARGET_DISK="$CLA_TARGET_DISK"                      
[ ! -z "$CLA_TARGET_PART"           ] && TARGET_PART="$CLA_TARGET_PART"                      
[ ! -z "$CLA_TARGET_MOUNT"          ] && TARGET_MOUNT="$CLA_TARGET_MOUNT"                      
[ ! -z "$CLA_BOOTSTRAP_PART"        ] && BOOTSTRAP_PART="$CLA_BOOTSTRAP_PART"                      
[ ! -z "$CLA_SYSTEM_BOOTSTRAP"      ] && SYSTEM_BOOTSTRAP="$CLA_SYSTEM_BOOTSTRAP"
[ ! -z "$CLA_SYSTEM_HOSTNAME"       ] && SYSTEM_HOSTNAME="$CLA_SYSTEM_HOSTNAME"
[ ! -z "$CLA_VOYAGE_SYSTEM_SERIAL"  ] && VOYAGE_SYSTEM_SERIAL="$CLA_VOYAGE_SYSTEM_SERIAL"                      
[ ! -z "$CLA_VOYAGE_SYSTEM_CONSOLE" ] && VOYAGE_SYSTEM_CONSOLE="$CLA_VOYAGE_SYSTEM_CONSOLE"                      
[ ! -z "$CLA_DISTDIR"               ] && DISTDIR="$CLA_DISTDIR"                             
[ ! -z "$CLA_MAKEFS"                ] && MAKEFS="$CLA_MAKEFS"                             

if [ "$run_dialog" = 1 ]; then 

	# here we define the different choices which can be made by the user
	# OPTIONS-Format: option "%" option "%" option
	# option-Format:  number ":" description ":" preset (here: by command line)
	OPTIONS="1:Specify Distribution Directory:$CLA_DISTDIR%2:Select Target Profile:$CLA_VOYAGE_PROFILE%3:Select Target Disk:$CLA_TARGET_DISK%4:Select Target Bootstrap Loader:$CLA_SYSTEM_BOOTSTRAP%5:Configure Target Console:$CLA_VOYAGE_SYSTEM_CONSOLE%6:Partition and Create Filesystem:$CLA_MAKEFS%7:Copy Distribution to Target:1%8:Set hostname:$CLA_SYSTEM_HOSTNAME%9:Exit:1"
	
	opt=1
	while true
	do
	    opt=$((opt + 1))
	    if [ $opt -ge 8 ] ; then opt=8 ; fi
	    
	    # Work starts here.  The default is set to "2" at first
	    #ask_setting "What would you like to do?" "$OPTIONS" 8
	    ask_setting "What would you like to do?" "$OPTIONS" $opt
	    opt=$v
		case $v in
			1) ask_work_dir $DISTDIR "distribution";
			   DISTDIR=$w;;
			2) select-profile $DISTDIR;
			   if [ -z $w ]; then
			   	err_msg "Check Distribution Directory setting!\n\n";
			   fi;;
			3) select_target_disk;;
			4) select_target_boot;;
			5) select_target_console;;
			6) select_fs_creation;;
			7) confirm_copy_details;;
			8) update_hostname;;
			9) break;;
			*) err_quit "Invalid return code from ask_setting";;
		esac
	done
	
	write_config $CONFIGFILE "$CONFIGLIST"

	# Just for testing we write out the results to a local file
	write_config "test.conf" "$VOYAGE_CONF_LIST"
else 
    select-profile $DISTDIR run
	confirm_copy_details run
fi

