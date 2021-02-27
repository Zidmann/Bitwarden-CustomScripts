#!/bin/bash

# Auxiliary script to send a file on Google Cloud Storage

KEY=$1
shift;
FILEPATH="$*"

EXITCODE=0

# Load the common environment variables
DIRNAME="$(dirname "$(dirname "$(readlink -f "$0")")")"
source "$DIRNAME/conf/common.env"

echo " [i] Push $FILEPATH file"

## Definition of the exit function
exit_line () {
	local EXITCODE=$1
	exit "$EXITCODE"
}

## Check if the GCP configuration file exists
if [ ! -f "$GCP_CONF_FILE" ]
then
	echo "  [-] No configuration file found"
	exit_line 1
fi

## Check if the file to send exists
if [ ! -f "$FILEPATH" ]
then
	echo "  [-] No file to send"
	exit_line 1
fi

## Extract the distant bucket storage
DISTANTPATH=$(awk -F';' -v KEY_V="$KEY" '{if($1==KEY_V){print $2}}' "$GCP_CONF_FILE" 2>/dev/null | tail -n1)
if [ "$DISTANTPATH" == "" ]
then
	echo "  [-] Error no distant path identified for $KEY"
	exit_line 1
fi


## Send the file with gsutil tool
echo gsutil cp "$FILEPATH" "$DISTANTPATH"
RETURN_CODE=$?
if [ "$RETURN_CODE" != "0" ]
then
	echo "  [-] Error in the copy to the Google Cloud Platform"
	exit_line "$RETURN_CODE"
fi

## Move the file in the sent directory
mv "$DISTANTPATH" "$SENT_DATA_DIR/"
if [ "$RETURN_CODE" != "0" ]
then
	echo "  [-] Error in the move of the file to the sent files directory"
	exit_line "$RETURN_CODE"
fi

exit_line 0
