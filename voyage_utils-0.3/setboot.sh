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
		sercmd="serial=0,${VOYAGE_SYSTEM_SERIAL}n8"
		serapp="console=ttyS0,${VOYAGE_SYSTEM_SERIAL}n8 "
	else
		sercmd=""
		serapp=""
	fi
	# generate our lilo config file
	cat > $TARGET_MOUNT/etc/lilo.install.conf << EOM
#
# This file generated automatically by $0
# on `date`
#
boot = $TARGET_DISK
disk = $TARGET_DISK
	bios = 0x80
$sercmd
vga=normal
delay=1
default=Linux

image=/vmlinuz
	root=/dev/hda$TARGET_PART
	label=Linux
		append="${serapp}reboot=bios"
	read-only

image=/vmlinuz.old
	root=/dev/hda$TARGET_PART
	label=LinuxOLD
		append="${serapp}reboot=bios"
	read-only
	optional
EOM
	sed -e "/disk =/d;/bios =/d" -e "s#${TARGET_DISK}#hda#" \
		$TARGET_MOUNT/etc/lilo.install.conf > \
		$TARGET_MOUNT/etc/lilo.conf
}

update_lilo() 
{
	local liloconf newlilo

	make_lilo_conf
	chroot $TARGET_MOUNT lilo -C /etc/lilo.install.conf || \
	  err_quit "Failed to chroot to $MOUNTDISK to install lilo"
}

#
# For a grub install, we try to be clever (maybe too clever?) and check
# whether the boot partition seems to already have grub installed.  If it
# does, then we only need to add the current kernel image to the menu.
#
# If grub is not yet installed, there is a lot more work to be done :-)
#
update_grub()
{
	local console datestr fname gp prolog res
	# if the boot partition is separate from the main one,
	# mount it on $TARGET_MOUNT/rw, otherwise it will be
	# $TARGET_MOUNT/boot
	if [ $BOOTSTRAP_PART -ne $TARGET_PART ]; then
		gp=${TARGET_MOUNT}/rw
		mount -t ext2 ${TARGET_DISK}${BOOTSTRAP_PART} $gp || \
		  err_quit "Failed to mount ${TARGET_DISK}${BOOTSTRAP_PART} on $gp"
	else
		gp=${TARGET_MOUNT}/boot
	fi
	if [ ! -d ${gp}/grub ]; then
		# create the grub directory in the boot partition
		mkdir ${gp}/grub
		# copy the grub files into it
		cp ${TARGET_MOUNT}/lib/grub/i386-pc/* ${gp}/grub
		# create a grub device map for the installation
		# using a temporary file
		fname=`mktemp`
		echo "(hd0) $TARGET_DISK" > $fname
		# note the arithmetic evaluation (grub uses '0' as
		# the first partition)
		res=`$chroot grub --device-map=$fname <<EOM
setup (hd0) (hd0,$(($BOOTSTRAP_PART-1)))
quit
EOM`
		if [ $? -ne 0 ]; then
			err_quit "Trouble running grub - dialog was: $res"
		fi
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

	# generate a label with today's date
	# and append to menu.lst
	datestr=`date +%d%b%y`
	cat <<EOM >> ${gp}/grub/menu.lst

title voyage-linux-$datestr
root (hd0,$(($TARGET_PART-1)))
kernel /vmlinuz root=/dev/hda${TARGET_PART}${console}
EOM
	if [ $BOOTSTRAP_PART -ne $TARGET_PART ]; then
		umount ${TARGET_DISK}${BOOTSTRAP_PART} || \
		  err_quit "Failed to unmount ${TARGET_DISK}${BOOTSTRAP_PART}"
	fi
}

###############################################
#    Mainline code starts here                #
###############################################

	if [ $VOYAGE_SYSTEM_BOOTSTRAP != grub -a $VOYAGE_SYSTEM_BOOTSTRAP != lilo ]; then
		select_target_boot
	fi

	if [ $VOYAGE_SYSTEM_BOOTSTRAP == lilo ]; then
		make_lilo_conf
		update_lilo
	else
		update_grub
	fi

	
