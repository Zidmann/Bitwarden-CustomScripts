#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will be used to backup the bwdata directory
##################################################################################
## 2021/02/24 - First release of the script
##################################################################################


##################################################################################
# Beginning of the script - definition of the variables
##################################################################################
SCRIPT_VERSION="0.0.1"

# Return code
RETURN_CODE=0

# Flag to execute the exit function
EXECUTE_EXIT_FUNCTION=0

# Trap management
function exit_function_auxi(){
	if [ -f "$AES_KEY_TMP_PATH" ]
	then
		echo "------------------------------------------------------"
		echo "[i] Removing completly the temporary AES key $AES_KEY_TMP_PATH"
		shred -n 1 -uz "$AES_KEY_TMP_PATH"
	fi

	if [ -f "$ARCHIVE_TMP_PATH" ]
	then
		echo "------------------------------------------------------"
		echo "[i] Removing completly the temporary archive $ARCHIVE_TMP_PATH"
		shred -n 1 -uz "$ARCHIVE_TMP_PATH"
	fi

	if [ -f "$ENCRYPTED_AES_KEY_TMP_PATH" ]
	then
		echo "------------------------------------------------------"
		echo "[i] Removing the temporary encrypted AES key $ENCRYPTED_AES_KEY_TMP_PATH"
		rm "$ENCRYPTED_AES_KEY_TMP_PATH"
	fi

	if [ -f "$ENCRYPTED_ARCHIVE_TMP_PATH" ]
	then
		echo "------------------------------------------------------"
		echo "[i] Removing the temporary encrypted archive $ENCRYPTED_ARCHIVE_TMP_PATH"
		rm "$ENCRYPTED_ARCHIVE_TMP_PATH"
	fi

	# Elapsed time - end date and length
	if [ "$BEGIN_DATE" != "" ]
	then 
		END_DATE=$(date +%s)
		ELAPSED_TIME=$((END_DATE - BEGIN_DATE))

		echo "------------------------------------------------------"
		echo "Elapsed time : $ELAPSED_TIME sec"
		echo "Ending time  : $(date)"
	fi
	echo "------------------------------------------------------"
	echo "Exit code = $RETURN_CODE"
	echo "------------------------------------------------------"
}
function exit_function(){
	if [ "$EXECUTE_EXIT_FUNCTION" != "0" ]
	then
		if [ -f "$LOG_PATH" ]
		then
			exit_function_auxi | tee -a "$LOG_PATH"
		else
			exit_function_auxi
		fi
	fi
}
function interrupt_script_auxi(){
	echo "------------------------------------------------------"
	echo "[-] A signal $1 was trapped"
}
function interrupt_script(){
	if [ -f "$LOG_PATH" ]
	then
		interrupt_script_auxi "$1" | tee -a "$LOG_PATH"
	else
		interrupt_script_auxi "$1"
	fi
}

trap exit_function              EXIT
trap "interrupt_script SIGINT"  SIGINT
trap "interrupt_script SIGQUIT" SIGQUIT
trap "interrupt_script SIGTERM" SIGTERM

# Analysis of the path and the names
DIRNAME=$(dirname "$(dirname "$(readlink -f "$0")")")
CONF_DIR="$DIRNAME/conf"

PREFIX_NAME=$(basename "$(readlink -f "$0")")
NBDELIMITER=$(echo "$PREFIX_NAME" | awk -F"." '{print NF-1}')

if [ "$NBDELIMITER" != "0" ]
then
	PREFIX_NAME=$(echo "$PREFIX_NAME" | awk 'BEGIN{FS="."; OFS="."; ORS="\n"} NF{NF-=1};1')
fi

if [ -f "$CONF_DIR/$PREFIX_NAME.env" ]
then
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
elif [ -f "$CONF_DIR/backup_bitwarden.env" ]
then
	PREFIX_NAME="backup_bitwarden"
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
else
	echo "[-] Impossible to find a valid configuration file"
	exit "$RETURN_CODE"
fi

# Loading configuration file
source "$CONF_PATH"
LOG_DIR="$DIRNAME/log"
TMP_DIR="$DIRNAME/tmp"

# Log file path
LOG_PATH=${1:-"${LOG_DIR}/$PREFIX_NAME.$(hostname).$TODAYDATE.$TODAYTIME.log"}
mkdir -p "$(dirname "$LOG_PATH")"

# Temporary file path
AES_KEY_TMP_PATH="$TMP_DIR/$AES_KEY_FILENAME.$PREFIX_NAME.1.$$.tmp"
ARCHIVE_TMP_PATH="$TMP_DIR/$ARCHIVE_FILENAME.$PREFIX_NAME.2.$$.tmp"
ENCRYPTED_AES_KEY_TMP_PATH="$TMP_DIR/$ENCRYPTED_AES_KEY_FILENAME.$PREFIX_NAME.3.$$.tmp"
ENCRYPTED_ARCHIVE_TMP_PATH="$TMP_DIR/$ENCRYPTED_ARCHIVE_FILENAME.$PREFIX_NAME.4.$$.tmp"
mkdir -p "$(dirname "$AES_KEY_TMP_PATH")"
mkdir -p "$(dirname "$ARCHIVE_TMP_PATH")"
mkdir -p "$(dirname "$ENCRYPTED_AES_KEY_TMP_PATH")"
mkdir -p "$(dirname "$ENCRYPTED_ARCHIVE_TMP_PATH")"

# Data directory
mkdir -p "$DATA_DIR"

# Elapsed time - begin date
BEGIN_DATE=$(date +%s)

EXECUTE_EXIT_FUNCTION=1

# Main paths
SECURE_KEY_PATH="$CONF_DIR/$SECURE_KEY_FILENAME"
ENCRYPTED_AES_KEY_PATH="$DATA_DIR/$ENCRYPTED_AES_KEY_FILENAME"
ENCRYPTED_ARCHIVE_PATH="$DATA_DIR/$ENCRYPTED_ARCHIVE_FILENAME"

##################################################################################
# 
##################################################################################
function main_code(){
	echo ""
	echo "======================================================"
	echo "======================================================"
	echo "= SCRIPT TO BACKUP BITWARDEN DIRECTORIES             ="
	echo "======================================================"
	echo "======================================================"

	echo "Starting time : $(date)"
	echo "Version : $SCRIPT_VERSION"
	echo ""
	echo "LOG_PATH=$LOG_PATH"
	echo "AES_KEY_TMP_PATH=$AES_KEY_TMP_PATH"
	echo "ARCHIVE_TMP_PATH=$ARCHIVE_TMP_PATH"
	echo "ENCRYPTED_AES_KEY_TMP_PATH=$ENCRYPTED_AES_KEY_TMP_PATH"
	echo "ENCRYPTED_ARCHIVE_TMP_PATH=$ENCRYPTED_ARCHIVE_TMP_PATH"
	echo ""
	echo "SECURE_KEY_PATH=$SECURE_KEY_PATH"
	echo "ENCRYPTED_AES_KEY_PATH=$ENCRYPTED_AES_KEY_PATH"
	echo "ENCRYPTED_ARCHIVE_PATH=$ENCRYPTED_ARCHIVE_PATH"

	echo "----------------------------------------------------------"
	echo "[i] Creating an encryption key"
	openssl rand -out "$AES_KEY_TMP_PATH" 32
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	echo "----------------------------------------------------------"
	echo "[i] Making the archive of the Bitwarden directory"
	tar -zvcf "$ARCHIVE_TMP_PATH" "$BW_DATA"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	echo "----------------------------------------------------------"
	echo "[i] Encrypting the encryption key"
	openssl rsautl -encrypt -pubin -inkey "$SECURE_KEY_PATH" -in "$AES_KEY_TMP_PATH" -out "$ENCRYPTED_AES_KEY_TMP_PATH"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	echo "----------------------------------------------------------"
	echo "[i] Encrypting the archive"
	openssl enc -aes-256-cbc -pbkdf2 -pass file:"$AES_KEY_TMP_PATH" -in "$ARCHIVE_TMP_PATH" -out "$ENCRYPTED_ARCHIVE_TMP_PATH"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	echo "----------------------------------------------------------"
	echo "[i] Moving the encrypted key and archive"
	mv "$ENCRYPTED_AES_KEY_TMP_PATH" "$ENCRYPTED_AES_KEY_PATH"
	mv "$ENCRYPTED_ARCHIVE_TMP_PATH" "$ENCRYPTED_ARCHIVE_PATH"

	exit "$RETURN_CODE"
}
main_code 2>&1 | tee -a "$LOG_PATH"
RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

##################################################################################
exit "$RETURN_CODE"
