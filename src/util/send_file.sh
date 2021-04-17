#!/bin/bash

# Auxiliary script to send a file on Google Cloud Storage

KEY=$1
shift;
FILEPATH="$*"

EXITCODE=0

# Load the common environment variables
DIRNAME="$(dirname "$(dirname "$(readlink -f "$0")")")"

echo " [i] Push $FILEPATH file"
source "$DIRNAME/conf/common.env"
if [ "$?" != "0" ]
then
	echo "[-] Impossible to source the configuration file"
	exit 1
fi;

## Definition of the exit function
exit_line () {
	local EXITCODE=$1
	exit "$EXITCODE"
}

## Check if the GCP configuration file exists
GCP_CONF_FILE="$CONF_DIR/gcp.conf"
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

## Check if the service account key file exists
SERVICE_ACCOUNT_KEY_FILE="$CONF_DIR/$SERVICE_ACCOUNT_CREDENTIAL"
if [ ! -f "$SERVICE_ACCOUNT_KEY_FILE" ]
then
	echo "  [-] No service account key file found"
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
export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_KEY_FILE"
echo gsutil cp "$FILEPATH" "$DISTANTPATH"
RETURN_CODE=$?
if [ "$RETURN_CODE" != "0" ]
then
	echo "  [-] Error in the copy to the Google Cloud Platform"
	exit_line "$RETURN_CODE"
fi

## Move the file in the sent files directory
mv "$FILEPATH" "$SENT_DATA_DIR/"
if [ "$RETURN_CODE" != "0" ]
then
	echo "  [-] Error in the move of the file to the sent files directory"
	exit_line "$RETURN_CODE"
fi

exit_line 0
