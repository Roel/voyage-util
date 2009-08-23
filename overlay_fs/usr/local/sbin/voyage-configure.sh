#!/bin/sh
#################################################################
#
# voyage-configure.sh
#
#################################################################

if [ ! -f /etc/voyage.conf ] ; then
	echo "voyage.conf not found"
fi

. /etc/voyage.conf

# VOYAGE_SYSTEM_PCMCIA 
if [ "$VOYAGE_SYSTEM_PCMCIA" == "yes" ] ; then
	update-rc.d pcmcia defaults 20 >&2
else
	update-rc.d -f pcmcia remove  >&2
fi

# VOYAGE_SYSTEM_SERIAL
if [ "$VOYAGE_SYSTEM_SERIAL" == "" ] ; then
	sed -i -e "/^#[0-9]/ s/^#//" -e "s/^T0:/#T0:/" /etc/inittab
else
	sed -i -e "/^[0-9]:/ s/^/#/" -e "s/^#T0:/T0:/" /etc/inittab
fi
