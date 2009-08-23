#	Function select_profile()
#	This function generates a list of all the profile files present
#	in the profile directory (${base}/etc/voyage-profiles), with
#	the name of the profile defined within the file.  It then asks
#	the user to choose which profile he wants to use
#	Params:	$1 - the base directory name
#	Returns: $w contains the profile name (NULL if error)
#		 environment variable VOYAGE_PROFILE updated if no error
#
select-profile() {
local filelist filename pro proix prolist saveifs var
# Have a "sanity check" to assure the profile directory exists
if [ ! -d $1/etc/voyage-profiles ]; then
	err_msg "No voyage-profiles directory in $1/etc"
	w=""
	return
fi

# To get a clean directory list, we want to "cd" into the profile directory.
cd $1/etc/voyage-profiles
# generate a list of all the files
prolist=""
filelist=""
for filename in *; do
	if [ -f $filename ]; then
		# get the internal profile name
		pro=`grep VOYAGE_PROFILE $filename | sed -e "s/VOYAGE_PROFILE=//"`
		# if there are quotes or apostrophes, delete them
		pro=${pro//[\"\']/}
		if [ "$pro" ]; then
			if [ "$prolist" ]; then
				prolist="$prolist%$pro"
			else
				prolist=$pro
			fi
			if [ "$filelist" ]; then
				filelist=$filelist%$filename
			else
				filelist=$filename
			fi
		fi
	fi
done

# restore our directory
cd $RUNDIR
# Get current setting of $VOYAGE_PROFILE to use as user's default
# in the following call to ask_setting (list_str returns ix in $v)
list_str "$prolist" "$VOYAGE_PROFILE"

# Now that we have the data, present it to the user
# (ask_setting returns the user's choice in $v)
ask_setting "Please select Voyage profile:" "$prolist" $v
# save the user's choice - we'll need it when we fetch the file contents
proix=$v

list_str "$prolist" "$VOYAGE_PROFILE"
# Translate the numeric choice into the corresponding profile name
# (list_ix returns the name in $w)
list_ix "$prolist" $v

# Since the user has chosen to take a "preset" profile, we must get
# rid of any stored config settings.  All profile settings begin with
# "VOYAGE_", so we can go through $CONFLIST and remove those
saveifs=$IFS
IFS="%"
for var in $CONFIGLIST; do
	if [ ${var/#VOYAGE_*/VOYAGE_} == VOYAGE_ ]; then
		delete_config_var $var CONFIGLIST
		unset $var
	fi
done
IFS=$saveifs
# Similarly, we clear the current profile
VOYAGE_CONF_LIST=""
# save the value
VOYAGE_PROFILE="$w"
save_config_var VOYAGE_PROFILE VOYAGE_CONF_LIST
save_config_var VOYAGE_PROFILE CONFIGLIST

# and then 'source' the file
list_ix "$filelist" $proix
read_config "$1/etc/voyage-profiles/$w" VOYAGE_CONF_LIST
}
