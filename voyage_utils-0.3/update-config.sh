#
#	The routines within this file are designed for use with the
#	Voyage Linux Distribution, and may be freely copied under the
#	terms given in file 'License'.
#
#	Copyright (C) 2006 William Brack <wbrack@mmm.com.hk>
#
#

# We define some functions to make the mainline code cleaner
#
#	Function update_modules
#	Uses VOYAGE_SYSTEM_MODULES to generate a list of modules to
#	be loaded during system boot
#	Params:	$1 - root directory of target
#
update_modules() {
	local saveifs modname buildlist
	saveifs=$IFS
	IFS=";"
	buildlist="
#
# These lines generated automatically by `basename $0`
# on `date`
#
"
	for modname in $VOYAGE_SYSTEM_MODULES; do
		rmspace=`echo $modname | sed -e "s/^ *//"`
		buildlist="$buildlist\n$rmspace"
	done
	IFS=$saveifs
	echo -e "$buildlist" >> $1/etc/modules
}

#
#	Function update_inittab()
#	Modifies /etc/inittab to take account of whether or not
#	there is a serial console
#	Params: $1 - location of the root directory for input file
#		$2 - location of the root directory for the result
#	Result: 
#
update_inittab() {
  if [ $VOYAGE_SYSTEM_CONSOLE == serial ]; then
    cmd1="/^[0-9]:/ s/^/#/"
    cmd2="s/^#T0:/T0:/;s/ttyS0 .*00/ttyS0 ${VOYAGE_SYSTEM_SERIAL}/"
  else
    cmd1="/^[0-9]:/ s/^/#/"
    cmd2="s/&T0:/#T0:/"
  fi
  cat $1/etc/inittab | sed -e "$cmd1" | sed -e "$cmd2" > \
    $2/etc/inittab
}

#
#	Function update_pcmcia()
#	Sets the target system to take account of whether or not
#	there is pcmcia hardware present
#	Params:	$1 - root directory of target
#
update_pcmcia() {
  check_yn $VOYAGE_SYSTEM_PCMCIA
  if [ $? -le 0 ]; then
    echo "Removing pcmcia from update-rc.d" >&2
    chroot $1 update-rc.d -f pcmcia remove >&2
  fi
}

