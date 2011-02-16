#!/bin/bash

TARGET_DISK=""
TARGET_PART=""
SYSTEM_BOOT="1"
DONT_ASK="0"

# no here-document here. 
# this may be called from a read-only (live) file system
# where the mandatory tmp file for here-douments can't be 
# created. ottherwise you may get:
# "cannot create temp file for here document: Read-only file system"
usage () {
	echo "$0 -t <disk> [ -b { 1 | 2 | 3 | 4 } ] [ -y ]"
	echo "    -t  target disk device"
	echo "    -b  target partition number (default: 1)"
	echo "    -y  don't prompt for confirmance (default: prompt)"
	echo "legacy mode:"
	echo "$0 <device>"
	echo ""
}


#
# usage:
#	doopt "$@"
#
# returns:
#	$TARGET_DISK
#	$SYSTEM_BOOT
#	$DONT_ASK
#
doopt () {
	# for backward compatibility	
	if [ $# = 1 ]; then 
		TARGET_DISK="$1"
		return;
	fi

	local x
	while [ $# -gt 0 ]; do
		x="$1"; shift

		case "$x" in 
		-t) TARGET_DISK="$1"
			shift
			;;
		-b) SYSTEM_BOOT="$1"
			shift
			;;
		-y) DONT_ASK=1
			;;
		*) usage
			exit 1
			;;
		esac
	done
}

doopt "$@"

if [ -z "$SYSTEM_BOOT" -o -z "$TARGET_DISK" ]; then 
	usage
	exit 1
fi 

if [ "$DONT_ASK" = 0 ]; then 
	echo "Press ENTER to continue to format flash memory on $TARGET_DISK"
	read a
fi

TARGET_PART=$TARGET_DISK$SYSTEM_BOOT
case "$SYSTEM_BOOT" in
	1) SFDISKCMD='0,,L,*\n;\n;\n;'
	   ;;
	2) SFDISKCMD='0,0,\n0,,L,*\n;\n;'
	   ;;
	3) SFDISKCMD='0,0,\n0,0,\n0,,L,*\n;'
	   ;;
	4) SFDISKCMD='0,0,\n0,0,\n0,0,\n0,,L,*'
	   ;;
	*) usage
           exit 1
	   ;;
esac
	

[ -b "$TARGET_DISK" ] && echo -e "$SFDISKCMD" | sfdisk "$TARGET_DISK"
[ -b "$TARGET_PART" ] && { 
	mkfs.ext3 $TARGET_PART
	tune2fs -c 1 $TARGET_PART -L ROOT_FS
}
