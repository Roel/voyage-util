#!/bin/bash

if [ ! "${HAVESCRIPTUTILS:+present}" ]; then
	echo "This script must be run under voyage.update" >&2
	exit
fi

#
#	Function make_lilo_conf()
#	Creates two lilo config files on $TARGET_MOUNT - one for installation
#	(/etc/lilo.install.conf) and one for the runtime system
#	(/etc/lilo.conf).  Uses the VOYAGE_SYSTEM_xxxx and TARGET_xxxx
#	environment variables to control the generation
make_lilo_conf() {
	local liloconf newlilo sercmd serapp
	
	# First decide whether console is normal or serial
	if [ $VOYAGE_SYSTEM_CONSOLE == serial ]; then
		delay="delay=20"
		sercmd="serial=0,${VOYAGE_SYSTEM_SERIAL}n8"
		serapp="console=ttyS0,${VOYAGE_SYSTEM_SERIAL}n8 "
	else
		delay="delay=1"
		sercmd=""
		serapp=""
	fi
	#
	# Generate our lilo config file
	# Note that the 'boot', 'disk' and 'bios' params allow us
	# to run lilo on our host machine, setting up the disk for
	# our target machine.
	#
	cat > $TARGET_MOUNT/etc/lilo.install.conf << EOM
#
# This file generated automatically by $0
# on `date`
#
boot = $TARGET_DISK
disk = $TARGET_DISK
	bios = 0x80
$delay
$sercmd
vga=normal
default=Linux

image=/vmlinuz
	label=Linux
	initrd=/initrd.img
	read-only
	append="root=LABEL=ROOT_FS ${serapp}reboot=bios"

image=/vmlinuz.old
	label=LinuxOLD
	initrd=/initrd.img.old
	read-only
	append="root=LABEL=ROOT_FS ${serapp}reboot=bios"
	optional
EOM
	sed -e "/disk =/d;/bios =/d" -e "s#${TARGET_DISK}#/dev/hda#" \
		$TARGET_MOUNT/etc/lilo.install.conf > \
		$TARGET_MOUNT/etc/lilo.conf
}

update_lilo() 
{
	local liloconf newlilo

	echo "" >&2
	echo "Running lilo ...." >&2
	# Generate the configuration file
	make_lilo_conf
	
	# Set up /dev and /proc on target to use host devices
	mount -o bind /dev ${TARGET_MOUNT}/dev
	mount -o bind /proc ${TARGET_MOUNT}/proc
	chroot $TARGET_MOUNT lilo -C /etc/lilo.install.conf
	# Save the exit status, to check after umount'ing device stuff
	res=$?
	# Undo the previous 2 mounts
	umount ${TARGET_MOUNT}/proc
	umount ${TARGET_MOUNT}/dev
	# Check the saved exit status
	if [ $res -ne 0 ]; then
		err_quit "Failure during chroot to $MOUNTDISK to run lilo"
	fi
}

#
# For a grub install, we try check whether the boot partition seems to
# already have grub installed.  If it does, then we only need to add
# the current kernel image to the menu.
#
# If grub is not yet installed, we must install it.
#
update_grub()
{
	local console datestr fname gp prolog res

	# if the boot partition is separate from the main one,
	# mount it on $TARGET_MOUNT/rw, otherwise it will be
	# $TARGET_MOUNT/boot
	# $ghome is the name relative to the voyage target directory
	# $gp is the full pathname to where the grub directory is
	if [ $BOOTSTRAP_PART -ne $TARGET_PART ]; then
		ghome=/rw
		gp=${TARGET_MOUNT}${ghome}
		mount ${TARGET_DISK}${BOOTSTRAP_PART} $gp || \
		  err_quit "Failed to mount ${TARGET_DISK}${BOOTSTRAP_PART}" \
			   " on $gp"
	else
		ghome=/boot
		gp=${TARGET_MOUNT}${ghome}
	fi
	if [ ! -d ${gp}/grub ]; then
		# create the grub directory in the boot partition
		mkdir ${gp}/grub
		# copy the grub files into it
		if [ -d ${TARGET_MOUNT}/lib/grub/i386-pc/ ] ; then 
			cp ${TARGET_MOUNT}/lib/grub/i386-pc/* ${gp}/grub
		elif [ -d ${TARGET_MOUNT}/usr/lib/grub/i386-pc/ ] ; then 
			cp ${TARGET_MOUNT}/usr/lib/grub/i386-pc/* ${gp}/grub
		elif [ -d ${TARGET_MOUNT}/lib/grub/x86_64-pc/ ] ; then 
			cp ${TARGET_MOUNT}/lib/grub/x86_64-pc/* ${gp}/grub
		elif [ -d ${TARGET_MOUNT}/usr/lib/grub/x86_64-pc/ ] ; then 
			cp ${TARGET_MOUNT}/usr/lib/grub/x86_64-pc/* ${gp}/grub
		else
			err_quit "Can't find grub files - exiting"
		fi
		# create a grub device map for the installation
		dm="/grub/device.map"
		echo "(hd0) $TARGET_DISK" > ${gp}${dm}
		# We are going to 'chroot' over to our target, but because
		# we will be running 'grub' there, we will need the /dev
		# directory from our current system.
		mount -o bind /dev $TARGET_MOUNT/dev

		# note the arithmetic evaluation (grub uses '0' as
		# the first partition)
		res=`chroot $TARGET_MOUNT /usr/sbin/grub \
			--device-map=${ghome}${dm} 2>&1 <<EOM
setup (hd0) (hd0,$(($BOOTSTRAP_PART-1)))
quit
EOM`
		if [ $? -ne 0 ]; then
			umount $TARGET_MOUNT/dev
			err_quit "Trouble running grub - dialog was: $res"
		fi
		umount $TARGET_MOUNT/dev
		rm -f ${gp}${dm}
	fi

	# common code whether grub already installed or not
	if [ $VOYAGE_SYSTEM_CONSOLE == serial ]; then
		prolog="serial --speed=$VOYAGE_SYSTEM_SERIAL
terminal serial
"
		console=" console=ttyS0,${VOYAGE_SYSTEM_SERIAL}n8"
	else
		prolog=""
		console=""
	fi
	
	# sanity - if menu.lst doesn't exist, create it
	# (this will always happen on a new installation)
	if [ ! -f ${gp}/grub/menu.lst ]; then
		cat <<EOM > ${gp}/grub/menu.lst
#
# This file generated automatically by $0
# on `date`
#
$prolog
timeout 5
default 0
EOM
	fi

	# This will test if /initrd.img exist, then grub will enable initrd
	# and append to menu.lst
	if [ -f ${TARGET_MOUNT}/initrd.img ] ; then
		VOYAGE_INITRD="initrd /initrd.img"
	fi

	# generate a label with today's date
	# and append to menu.lst
	datestr=`date +%d%b%y`
	cat <<EOM >> ${gp}/grub/menu.lst

title voyage-linux-$datestr
root (hd0,$(($TARGET_PART-1)))
kernel /vmlinuz root=LABEL=ROOT_FS ${console}
${VOYAGE_INITRD}

EOM
	if [ $BOOTSTRAP_PART -ne $TARGET_PART ]; then
		umount ${TARGET_DISK}${BOOTSTRAP_PART} || \
		  err_quit "Failed to unmount ${TARGET_DISK}${BOOTSTRAP_PART}"
	fi
}

###############################################
#    Mainline code starts here                #
###############################################

	if [ $SYSTEM_BOOTSTRAP != grub -a \
	     $SYSTEM_BOOTSTRAP != lilo ]; then
		select_target_boot
	fi

	if [ $SYSTEM_BOOTSTRAP == lilo ]; then
		make_lilo_conf
		update_lilo
	else
		update_grub
	fi

	
