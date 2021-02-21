#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will be used to maintain the last version of the packages to
## ensure the security of the system
##################################################################################
## 2021/02/20 - First release of the script
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
	echo "------------------------------------------------------"
	if [ -f "$TMP_PATH" ]
	then
		echo "[i] Removing the temporary file $TMP_PATH"
		rm "$TMP_PATH" 2>/dev/null
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
elif [ -f "$CONF_DIR/upgrade_system.env" ]
then
	PREFIX_NAME="upgrade_system"
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

# Temporaryfile path
TMP_PATH="$TMP_DIR/$PREFIX_NAME.1.$$.tmp"
mkdir -p "$(dirname "$TMP_PATH")"

# Elapsed time - begin date
BEGIN_DATE=$(date +%s)

##################################################################################
# First console actions - Printing the header and the variables
##################################################################################
EXECUTE_EXIT_FUNCTION=1
echo "" | tee -a "$LOG_PATH"
echo "======================================================" | tee -a "$LOG_PATH"
echo "======================================================" | tee -a "$LOG_PATH"
echo "= SCRIPT TO UPGRADE THE SYSTEM                       =" | tee -a "$LOG_PATH"
echo "======================================================" | tee -a "$LOG_PATH"
echo "======================================================" | tee -a "$LOG_PATH"

echo "Starting time : $(date)"   | tee -a "$LOG_PATH"
echo "Version : $SCRIPT_VERSION" | tee -a "$LOG_PATH"
echo ""                          | tee -a "$LOG_PATH"
echo "LOG_PATH=$LOG_PATH"        | tee -a "$LOG_PATH"
echo "TMP_PATH=$TMP_PATH"        | tee -a "$LOG_PATH"

##################################################################################
function main_code(){
	echo "----------------------------------------------------------"
	echo "[i] Updating the package lists"
	apt-get update

	echo "----------------------------------------------------------"
	echo "[i] Installing the last versions of the packages"
	apt-get upgrade -y

	echo "----------------------------------------------------------"
	echo "[i] Removing the unused dependencies"
	apt-get autoremove -y

	echo "----------------------------------------------------------"
	echo "[i] Upgrade the Bitwarden application using bitwarden user"
	su - bitwarden -c "$BW_DATA/bitwarden.sh update"
}

main_code 2>&1 | tee -a "$LOG_PATH"

##################################################################################
exit "$RETURN_CODE"
