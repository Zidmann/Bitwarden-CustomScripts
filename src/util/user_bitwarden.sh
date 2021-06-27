#!/bin/bash

# Auxiliary script to check if the current user is bitwarden

USERID=$UID
USER=$(whoami)

## Definition of the exit function
exit_line () {
	local EXITCODE=$1
	exit "$EXITCODE"
}

echo "----------------------------------"
echo " PRIVILEGE USER CHECK             "
echo "----------------------------------"

if [ "$USER" == "bitwarden" ]
then
	echo "[+] User is bitwarden (ID=$USERID)"
	exit_line 0
elif [ "$USER" == "" ]
then
	echo "[-] User is not identified"
	exit_line 2
else
	echo "[-] User $USER(ID=$USERID) is not bitwarden"
	exit_line 1
fi

