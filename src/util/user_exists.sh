#!/bin/bash

# Auxiliary script to check if user is root

USER="$*"
EXISTS=$(id "$USER" 2>/dev/null | wc -l)

## Definition of the exit function
exit_line () {
	local EXITCODE=$1
	exit "$EXITCODE"
}

echo "----------------------------------"
echo " USER EXISTENCE CHECK             "
echo "----------------------------------"

if [ "$EXISTS" == "1" ]
then
	echo "[+] User $USER exists"
	exit_line 0
else
	echo "[-] User $USER doesn't exist"
	exit_line 1
fi

