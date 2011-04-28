#!/bin/bash

if [ ! "${HAVESCRIPTUTILS:+present}" ]; then
	echo "This script must be run under voyage.update"
	exit
fi

# Just for testing we write out the results to a local file
write_config "test.conf" "$VOYAGE_CONF_LIST"
