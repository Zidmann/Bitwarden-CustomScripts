#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will be used to push encrypted archive and key on Google Cloud
## Storage
##################################################################################
## 2021/02/27 - First release of the script
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
elif [ -f "$CONF_DIR/push_data.env" ]
then
	PREFIX_NAME="push_data"
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
else
	echo "[-] Impossible to find a valid configuration file"
	exit "$RETURN_CODE"
fi

# Loading configuration file
source "$CONF_PATH"
LOG_DIR="$DIRNAME/log"

# Log file path
LOG_PATH=${1:-"${LOG_DIR}/$PREFIX_NAME.$(hostname).$TODAYDATE.$TODAYTIME.log"}
mkdir -p "$(dirname "$LOG_PATH")"

# Elapsed time - begin date
BEGIN_DATE=$(date +%s)

EXECUTE_EXIT_FUNCTION=1

##################################################################################
# 
##################################################################################
function main_code(){
	echo ""
	echo "======================================================"
	echo "======================================================"
	echo "= SCRIPT TO PUSH DATA TO CLOUD ENVIRONMENT           ="
	echo "======================================================"
	echo "======================================================"

	echo "Starting time : $(date)"
	echo "Version : $SCRIPT_VERSION"
	echo ""
	echo "LOG_PATH=$LOG_PATH"

	echo "----------------------------------------------------------"
	echo "[i] Sending the files in the data directory"
	echo "----------------------------------------------------------"
	echo " [i] Sending the encrypted archive files"
	find "$DATA_DIR" -type f -name "$ENCRYPTED_ARCHIVE_FILEPATTERN" -maxdepth 1 -exec "$UTIL_DIR/send_file.sh" "FILETAR" {} \;
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

	echo "----------------------------------------------------------"
	echo " [i] Sending the encrypted key files"
	find "$DATA_DIR" -type f -name "$ENCRYPTED_AES_KEY_FILEPATTERN" -maxdepth 1 -exec "$UTIL_DIR/send_file.sh" "FILEKEY" {} \;
	RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")
}

main_code 2>&1 | tee -a "$LOG_PATH"

##################################################################################
exit "$RETURN_CODE"
