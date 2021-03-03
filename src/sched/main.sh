#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will launch all the different scripts dedicated to maintain
## the Bitwarden hosting device
##################################################################################
## 2021/03/02 - First release of the script
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
DIRNAME="$(dirname "$(dirname "$(readlink -f "$0")")")"
CONF_DIR="$DIRNAME/conf"

PREFIX_NAME="$(basename "$(readlink -f "$0")")"
NBDELIMITER=$(echo "$PREFIX_NAME" | awk -F"." '{print NF-1}')

if [ "$NBDELIMITER" != "0" ]
then
	PREFIX_NAME=$(echo "$PREFIX_NAME" | awk 'BEGIN{FS="."; OFS="."; ORS="\n"} NF{NF-=1};1')
fi

if [ -f "$CONF_DIR/$PREFIX_NAME.env" ]
then
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
elif [ -f "$CONF_DIR/main.env" ]
then
	PREFIX_NAME="main"
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
else
	echo "[-] Impossible to find a valid configuration file"
	exit "$RETURN_CODE"
fi

# Sourcing the useful variables
source "$CONF_PATH"
LOG_DIR="$DIRNAME/log"

# Log file path
LOG_PATH="${LOG_DIR}/$PREFIX_NAME.$(hostname).$TODAYDATE.$TODAYTIME.log"
mkdir -p "$(dirname "$LOG_PATH")"

function main_code(){	echo ""
	echo "======================================================"
	echo "======================================================"
	echo "= HEAP SCRIPT TO SCHEDULE ALL THE ACTIONS            ="
	echo "======================================================"
	echo "======================================================"

	echo "Starting time : $(date)"
	echo "Version : $SCRIPT_VERSION"
	echo ""

	# Step 1 : Check if the user is root to have all the privilegies
	"$UTIL_DIR/user_root.sh"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	# Step 2 : Check if the user bitwarden exists
	"$UTIL_DIR/user_exists.sh" "bitwarden"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	# Step 3 : Check if the public key exists to encrypt backups
	"$UTIL_DIR/file_exists.sh" "$CONF_DIR/bitwarden.pem"
	RETURN_CODE=$?
	if [ "$RETURN_CODE" != "0" ]
	then
		exit "$RETURN_CODE"
	fi;

	# Step 4 : Backup and send the data in an external space
	"$BAT_DIR/backup_bitwarden.sh"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	"$BAT_DIR/push_data.sh"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	# Step 5 : Keep the last version of the operating system and of Bitwarden application
	"$BAT_DIR/upgrade_system.sh"
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	exit "$RETURN_CODE"
}

main_code 2>&1 | tee -a "$LOG_PATH"

##################################################################################
exit "$RETURN_CODE"
