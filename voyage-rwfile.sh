#!/bin/sh

# Info/Progress
I()
{
	echo "... $1"
}

# Warning/Error
W()
{
	echo "*** $1"
}

Usage()
{
	echo ""
	echo "Usage: `basename $0` <create|destroy|status> <file>" >&2
	echo ""
	echo "  create - relocate <file> to $RO_DIR and make <file> a symlink to $RW_DIR"
	echo "  destroy - delete <file> if it is a symlink to $RW_DIR and exists in $RO_DIR"
	echo "  status - check the status of <file>"
}

if [ -z $2 ] ; then
	W "<file> is missing"
	Usage
	exit 1
fi

if [ "${2:0:1}" != "/" ] ; then
	echo "$2 is not starting with "/""
	exit 1	
fi

RO_DIR=/ro
RW_DIR=/lib/init/rw

create()
{
	FILE=$1

	if [ -L $FILE ] ; then
		W "$FILE is already a symlink."
		return
	fi

    if [ ! -e $FILE ] ; then 
		W "$FILE not found, please make $FILE exist."
		return
	fi

	DIR="$RO_DIR"`dirname $FILE`
    if [ ! -d "$DIR" ] ; then 
		I "Creating new directory $DIR"
		mkdir -p $DIR 
	fi

	I "Relocate $FILE to "$RO_DIR""$FILE""
    mv "$FILE" "$DIR"/ 

    I "Making symlink $FILE to "$RW_DIR""$FILE""
    ln -sf "$RW_DIR""$FILE" "$FILE"

}

restore()
{
	FILE=$1

	if [ ! -L $FILE ]; then
		W "$FILE is not a symlink."
		return
	fi
	if [ ! -e "$RO_DIR""$FILE" ]; then
		W "Cannot found "$RO_DIR""$FILE"."
		return
	fi
	
	I "Removing symlink $FILE."
	rm "$FILE"

	I "Restoring "$RO_DIR""$FILE" to "$FILE"."
	mv "$RO_DIR""$FILE" `dirname "$FILE"`
}

status()
{
	FILE=$1
	
	if [ -L $FILE ]; then
		I "$FILE is a symlink."
	else
		I "$FILE is not a symlink."
	fi
	
	if [ -e "$RO_DIR""$FILE" ]; then
		I ""$RO_DIR""$FILE" exist."
	else
		I "Cannot found "$RO_DIR""$FILE"."
	fi

}

case "$1" in
	create)
		create $2
		;;
	restore)
		restore $2
		;;
	status)
		status $2
		;;
	*)
		Usage
		exit 1
		;;
esac

