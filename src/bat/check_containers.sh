#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will be used to check if the bitwarden Docker containers
## running on the host device have the appropriate versions and are running
## properly (status and health checks)
##################################################################################
## 2021/02/23 - First release of the script
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
	if [ -f "$TMP_PATH" ]
	then
		echo "------------------------------------------------------"
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
elif [ -f "$CONF_DIR/check_containers.env" ]
then
	PREFIX_NAME="check_containers"
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
TMP_PATH="$TMP_DIR/$PREFIX_NAME.1.$$.tmp"
mkdir -p "$(dirname "$TMP_PATH")"

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
	echo "= SCRIPT TO CHECK BITWARDEN DOCKER CONTAINERS        ="
	echo "======================================================"
	echo "======================================================"

	echo "Starting time : $(date)"
	echo "Version : $SCRIPT_VERSION"
	echo ""
	echo "LOG_PATH=$LOG_PATH"
	echo "TMP_PATH=$TMP_PATH"

	# List of the Bitwarden containers
	CONTAINER_NAMES=("bitwarden-nginx" "bitwarden-portal" "bitwarden-admin" "bitwarden-api" "bitwarden-attachments" "bitwarden-sso" "bitwarden-events" "bitwarden-web" "bitwarden-identity" "bitwarden-icons" "bitwarden-mssql" "bitwarden-notifications")

	echo "------------------------------------------------------"
	echo "[i] Browsing the container name list"
	for ((i=0; i<${#CONTAINER_NAMES[@]}; i++))
	do
		# Extracting the container name
		CONTAINER_NAME="${CONTAINER_NAMES[$i]}"
		echo " -----------------------------------------------------"
		echo " [i] Analyzing the $CONTAINER_NAME container"

		# Checking the status and the health of the container
		STATUS=$($UTIL_DIR/get_docker_info.sh "STATUS" "$CONTAINER_NAME")
		IS_UP=$(echo "$STATUS" | grep -c "^Up")
		IS_HEALTHY=$(echo "$STATUS" | grep -c "(healthy)$") 
		if [ "$IS_UP" == "1" ] && [ "$IS_HEALTHY" == "1" ]
		then
			echo "  [+] Container is up and healthy"
		elif [ "$IS_UP" != "1" ]
		then
			echo "  [-] Container is not up"
			RETURN_CODE=1
		elif [ "$IS_HEALTHY" != "1" ]
		then
			echo "  [-] Container is not healthy"
			RETURN_CODE=1
		fi

		# Checking the image name
		IMAGE=$($UTIL_DIR/get_docker_info.sh "IMAGE" "$CONTAINER_NAME")
		IMAGENAME=$(echo "$IMAGE" | awk -F':' '{print $1}' | awk -F' ' '{print $2}' | sed -r 's/[/]+/-/g')
		if [ "$IMAGENAME" == "$CONTAINER_NAME" ]
		then
			echo "  [-] Container name ($CONTAINER_NAME) is not image name ($IMAGENAME)"
			RETURN_CODE=1
		else
			# Checking the version of the container image
			COREVERSION=$(grep "COREVERSION=" "$BW_DIR/bitwarden.sh" | head -n1 | awk -F'=' '{print $2}' | awk -F'"' '{print $2}')
			WEBVERSION=$(grep "WEBVERSION=" "$BW_DIR/bitwarden.sh"   | head -n1 | awk -F'=' '{print $2}' | awk -F'"' '{print $2}')

			if [ "$CONTAINER_NAME" == "bitwarden-web" ]
			then
				EXPECTED_VERSION=$WEBVERSION
			else
				EXPECTED_VERSION=$COREVERSION
			fi

			VERSION=$(echo "$IMAGE" | awk -F':' '{print $NF}')
			if [ "$VERSION" == "$EXPECTED_VERSION" ]
			then
				echo "  [+] Version is correct ($VERSION)"
			else
				echo "  [-] Version is incorrect ($VERSION but expected is $EXPECTED_VERSION)"
				RETURN_CODE=1
			fi		
		fi
	done
}

main_code 2>&1 | tee -a "$LOG_PATH"

##################################################################################
exit "$RETURN_CODE"
