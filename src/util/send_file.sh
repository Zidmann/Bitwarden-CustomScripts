#!/bin/bash

# Auxiliary script to send a file on Google Cloud Storage

KEY=$1
shift;
FILEPATH="$*"

EXITCODE=0

# Load the common environment variables
DIRNAME="$(dirname "$(dirname "$(readlink -f "$0")")")"

echo " [i] Push $FILEPATH file"
if ! source "$DIRNAME/conf/common.env";
then
	echo "[-] Impossible to source the configuration file"
	exit 1
fi;

if ! source "$HOME/.bashrc";
then
	echo "[-] Impossible to source the bashrc file"
	exit 1
fi;

## Definition of the exit function
exit_line () {
	local EXITCODE=$1
	exit "$EXITCODE"
}

# Check the argument $KEY
if [ "$KEY" == "ARCHIVE" ]
then
	## Check if the GCP bucket dedicated to the archive is defined in the environment variable
	if [ -z "$BITWARDEN_BACKUP_TAR_BUCKET" ]
	then
		echo "  [-] Error no archive backup bucket defined"
		exit_line 1
	else
		DISTANTPATH="$BITWARDEN_BACKUP_TAR_BUCKET"
	fi
elif [ "$KEY" == "KEY" ]
then
	## Check if the GCP bucket dedicated to the keys is defined in the environment variable
	if [ -z "$BITWARDEN_BACKUP_KEY_BUCKET" ]
	then
		echo "  [-] Error no key backup bucket defined"
		exit_line 1
	else
		DISTANTPATH="$BITWARDEN_BACKUP_KEY_BUCKET"
	fi
else
	echo "  [-] Unknown key argument"
	exit_line 1
fi

## Check if the GCP service file path variable exists and if it designed a real file
if [ -z "$BITWARDEN_BACKUP_SA_PATH" ]
then
	echo "  [-] Error no service account path defined"
	exit_line 1
fi

if [ ! -f "$BITWARDEN_BACKUP_SA_PATH" ]
then
	echo "  [-] No service account key file found"
	exit_line 1
fi

## Check if the file to send exists
if [ ! -f "$FILEPATH" ]
then
	echo "  [-] No file to send"
	exit_line 1
fi

## Check if the distant path exists
if [ "$DISTANTPATH" == "" ]
then
	echo "  [-] Error no distant path identified for $KEY"
	exit_line 1
fi

## Send the file with gsutil tool
gsutil cp "$FILEPATH" "$DISTANTPATH"
RETURN_CODE=$?
if [ "$RETURN_CODE" != "0" ]
then
	echo "  [-] Error in the copy to the Google Cloud Platform"
	exit_line "$RETURN_CODE"
fi

## Move the file in the sent files directory
mv "$FILEPATH" "$SENT_DATA_DIR/"
RETURN_CODE=$?
if [ "$RETURN_CODE" != "0" ]
then
	echo "  [-] Error in the move of the file to the sent files directory"
	exit_line "$RETURN_CODE"
fi

exit_line 0
