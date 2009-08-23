#
#	The routines within this file are designed for use with the
#	Voyage Linux Distribution, and may be freely copied under the
#	terms given in file 'License'.
#
#	Copyright (C) 2006 William Brack <wbrack@mmm.com.hk>
#
#

HAVESCRIPTUTILS=1
#####################################################################
#                 General Utilities                                 #
#####################################################################

#
#	Function read_response
#	Read data from the user, then read the response
#	Params: $1 - string to echo for the request
#	        $2 - name of variable which will contain response
#
read_response() {
	echo -en "$1" >&2
	read $2
	echo >&2
}

#
#	Function check_yn()
#	Checks that it's param is 'y' or 'n', or one of the
#	common variations ("Y", "yes", "Yes", "YES")
#	Params: 1 - variable to be evaluated
#	Returns: 1 if 'y', 0 if 'n', -1 if undetermined
#
check_yn() {
	if [ "$1" == "y" -o "$1" == "yes" -o \
	     "$1" == "Y" -o "$1" == "Yes" -o \
	     "$1" == "YES" ]; then
	     	return 1
	fi
	if [ "$1" == "n" -o "$1" == "no" -o \
	     "$1" == "N" -o "$1" == "No" -o \
	     "$1" == "NO" ]; then
	     	return 0
	fi
	return -1
}

#
#	Function get_yn()
#	Asks a question and reads/validates a "y/n" response
#	Params: $1 - the question to be echo'ed - a " (y/n)?" will be appended
#	Returns: 1 for yes, 0 for no
#
get_yn() {
	local a
	while true
	do
		read_response "$1 (y/n)? " a
		check_yn "$a"
		if [ ! $? -lt 0 ]; then
			return $?
		fi
		echo "Invalid response '$a' - please answer with 'y' or 'n'" >&2
	done
}

#####################################################################
#	Error reporting routines                                    #
#####################################################################

#
#	Function err_quit()
#
#	Outputs a rude message and assures the install disk has been
#	unmounted
err_quit()
{
	echo "Fatal Error: $1" >&2
#	umount $MOUNTDISK 2>&1 > /dev/null
	exit
}

#	Similar routine for non-fatal error message
err_msg()
{
	echo -e "Error: $1" >&2
}

#####################################################################
#	Configuration variable routines                             #
#                                                                   #
#	Config variables are stored for subsequent runs.  The       #
#	routines maintain a list of variables which have been read, #
#	or are to be saved.  This should allow dynamic growth.      #
#####################################################################

#
#	Function read_config()
#	Reads config variables from a specified file
#
#	Params: $1-config file name
#		$2-param list name (not the list, the *name*)
read_config() {
	local saveifs vlist vdata vname ix
	if [ -f $1 ]; then
		vlist=`cat $1`
		# Set the variables
		savifs=$IFS
		IFS=$'\n'
		source $1
		# Now generate a list of what variables are present
		for ix in $vlist; do
			# First, because this comes from a user file, we
			# need to do a little editing.  The following 'sed'
			# is meant to remove leading&trailing spaces, and
			# delete any comments.  It's possible that the
			# resulting line will be empty, so we check for that
			# as well
			vdata=`echo $ix | sed -e "s/ *//;s/#.*//;s/ .*$//"`
			if [ -z $vdata ]; then
				continue
			fi
			# Isolate the variable name
			# by deleting everything from the '=' to EOL
			vname=${vdata%=*}
			# Save the variable in the list, and assure
			# it's exported
			save_config_var "$vname" "$2"
		done
		IFS=$saveifs
	fi
}

#
#	Function write_config()
#	Saves the specified configuration variables
#
#	Params: $1 - save file name
#		$2 - param list
write_config() {
	local ix saveifs var caller=`basename $0`
	saveifs=$IFS
	IFS="%"
	var=`date`
	{
		echo -e "#\n# This file generated automatically by $caller\n# on $var\n#\n"
		# Step through the variables in the list and write them out
		for ix in $2; do
			# if the value includes a space, put in quotes
			var=${!ix}
			if [ $var != ${var/ /X} ]; then
				echo $ix=\"${!ix}\"
			else
				echo $ix=${!ix}
			fi
		done
	} >$1
	IFS=$saveifs
}

#
#	Function save_config_var
#	Checks if a param is present in a list, and adds it if not
#	Params: $1-param name, $2-list name
save_config_var() {
	list_str "${!2}" "$1"
	if [ $v -eq 0 ]; then
		if [ "${!2}" != "" ]; then
			export $2="${!2}%"
		fi
		export $2="${!2}$1"
	fi
}
 
#	Function delete_config_var()
#	Checks if a param is present in a list, and if it is
#	deletes it.
#	Params:	$1 - param name
#		$2 - list name
delete_config_var() {
	local listent saveifs templist=""
	saveifs=$IFS
	# Need to set IFS for list processing
	IFS="%"
	# Fetch each item in list
	for listent in ${!2}; do
		# Copy if not the specified one, else ignore
		if [ "$listent" != "$1" ]; then
			if [ -z "$templist" ]; then
				templist="$listent"
			else
				templist="$templist%$listent"
			fi
		fi
	done
	IFS=$saveifs
	# Now reset the list to our new one
	export $2="$templist"
}

#####################################################################
#	Routines for working with lists                             #
#                                                                   #
#	I really wanted to use arrays of strings, but I was never   #
#	able to figure out how to pass an array as a 'positional    #
#	parameter' under Bash :-)                                   #
#                                                                   #
#	Our lists are (arrays) of strings, using a '%' as the       #
#	string separator.                                           #
#####################################################################

#
#	Function list_ix()
#	Params: $1=value list, $2=index
#	Returns: $w set to coresponding word in list (starts from 1)
#
list_ix()
{
	local saveifs cnt
	saveifs=$IFS
	IFS=%
	cnt=1
	for w in $1; do
		if [ $cnt -eq $2 ]; then
			IFS=$saveifs
			return
		fi
		cnt=$(($cnt+1))
	done
	w=""
	IFS=$saveifs
}

#
#	Function list_str()
#	Params: $1=value list, $2=string
#	Returns: %v set to corresponding position of word in list
#	         (0 if not found)
list_str()
{
	local arr ix count saveifs
	saveifs=$IFS
	IFS='%'
	count=0
	for ix in $1; do
		count=$(($count + 1))
		if [ "$ix" == "$2" ]; then
			v=$count
			IFS=$saveifs
			return
		fi
	done
	IFS=$saveifs
	v=0
}

#
#	Function ask_setting()
#	Params: $1=Question string, $2=Value list, $3=default
#	Returns: $v set to postion in list (starting from 1)
#
ask_setting()
{
	local len ix len default saveifs
	saveifs=$IFS
	IFS='%'
	while true
	do
		echo $1 >&2
		len=0
		# Calculate the length of the list, and find the default
		for ix in $2; do
			len=$(($len + 1))
			if [ "$3" -eq "$len" ]; then
				default=$ix
			fi
			echo "  $len - $ix" >&2
		done
		read_response "       (default=$3 [$default]): " v
		v=${v:-$3}
		if [ $v -ge 1 ]; then
			if [ $v -le $len ]; then
				break;
			fi
		fi
		echo "Unknown response, please try again" >&2
	done
	IFS=$saveifs
}

#
#	Function ask_work_dir()
#	Ask for the directory containing Voyage
#	Params:	$1 - default response
#		$2 - string for modifying prompt ('distribution' or 'install')
#	Returns: directory name in $w
ask_work_dir() 
{
	while true
	do
		read_response "Where is the Voyage Linux $2 directory?\n  (default=$1): " w
		w=${w:-$1}
		if [ ! -d $w ]; then
		  err_msg "$w is not a directory"
		  continue
		fi
		if [ ! -f $w/etc/voyage.conf ]; then
		  err_msg \
		    "$w does not seem to contain the Voyage Linux distrubution\n"
		else
		# Assure directory name is absolute
			cd $w
			w=$PWD
			cd $RUNDIR
			break
		fi
	done
}

#
#	Function get_serial_speed()
#	Queries the user for the baud rate and sets it into the
#	environment variable VOYAGE_SYSTEM_SERIAL
#	Parameters: $1 - default speed
#
get_serial_speed() {
	local v w x speedvals="2400%4800%9600%19200%38400%57600%115200"
	list_str "$speedvals" $1
	if [ "$v" == "" ]; then
		v=3
	fi
	ask_setting "Please choose speed:" "$speedvals" $v
	list_ix "$speedvals" $v
	VOYAGE_SYSTEM_SERIAL=$w
	save_config_var VOYAGE_SYSTEM_SERIAL CONFIGLIST
}
