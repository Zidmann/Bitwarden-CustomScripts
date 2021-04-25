#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## This script will check if the bitwarden is UP and restart it if necessary
##################################################################################
## 2021/04/05 - First release of the script
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
elif [ -f "$CONF_DIR/keep_up.env" ]
then
	PREFIX_NAME="keep_up"
	CONF_PATH="$CONF_DIR/$PREFIX_NAME.env"
else
	echo "[-] Impossible to find a valid configuration file"
	exit "$RETURN_CODE"
fi

# Loading configuration file
source "$CONF_PATH"
RETURN_CODE=$?
if [ "$RETURN_CODE" != "0" ]
then
	echo "[-] Impossible to source the configuration file"
	exit "$RETURN_CODE"
fi;

LOG_DIR="$DIRNAME/log"

# Log file path
LOG_PATH="${LOG_DIR}/$PREFIX_NAME.$(hostname).$TODAYDATE.$TODAYTIME.log"
mkdir -p "$(dirname "$LOG_PATH")"

# Elapsed time - begin date
BEGIN_DATE=$(date +%s)

EXECUTE_EXIT_FUNCTION=1

function main_code(){	echo ""
	echo "======================================================"
	echo "======================================================"
	echo "= SCRIPT TO KEEP BITWARDEN UP                        ="
	echo "======================================================"
	echo "======================================================"

	echo "Starting time : $(date)"
	echo "Version : $SCRIPT_VERSION"
	echo ""
	echo "LOG_PATH=$LOG_PATH"

	# List of the Bitwarden containers
	CONTAINER_NAMES=("bitwarden-nginx" "bitwarden-portal" "bitwarden-admin" "bitwarden-api" "bitwarden-attachments" "bitwarden-sso" "bitwarden-events" "bitwarden-web" "bitwarden-identity" "bitwarden-icons" "bitwarden-mssql" "bitwarden-notifications")

	# Checking all the containers are up
	echo "------------------------------------------------------"
	echo "[i] Browsing the container name list"
	FLAG_CONTAINER=0
	for ((i=0; i<${#CONTAINER_NAMES[@]}; i++))
	do
		# Extracting the container name
		CONTAINER_NAME="${CONTAINER_NAMES[$i]}"
		echo " -----------------------------------------------------"
		echo " [i] Analyzing the $CONTAINER_NAME container"

		# Checking the image name
		IMAGE=$("$UTIL_DIR/get_docker_info.sh" "IMAGE" "$CONTAINER_NAME")
		IMAGENAME=$(echo "$IMAGE" | awk -F':' '{print $1}' | awk -F' ' '{print $1}' | sed -r 's/[/]+/-/g')
		if [ "$IMAGENAME" == "" ]
		then
			echo "  [i] No container $CONTAINER_NAME found"
		elif [ "$IMAGENAME" != "$CONTAINER_NAME" ]
		then
			echo "  [-] Container name ($CONTAINER_NAME) is not image name ($IMAGENAME)"
			RETURN_CODE=1
		else
			FLAG_CONTAINER=1
 			STATUS=$("$UTIL_DIR/get_docker_info.sh" "STATUS" "$CONTAINER_NAME")
			if [ "$STATUS" == "running" ]
			then
				# Loop to wait the health check initialisation finished and get the status of the container (timeout is set to 5 min)
				STATUS_CHECK_BEGIN_DATE=$(date +%s)
				STATUS_CHECK_ELAPSED_TIME=0
				while [ $STATUS_CHECK_ELAPSED_TIME -lt 300 ]
				do
					# Checking the health of the container
					HEALTH=$("$UTIL_DIR/get_docker_info.sh" "HEALTH" "$CONTAINER_NAME")
					if [ "$HEALTH" != "starting" ]
					then
						break
					fi

					sleep 10
					STATUS_CHECK_END_DATE=$(date +%s)
					STATUS_CHECK_ELAPSED_TIME=$((STATUS_CHECK_END_DATE - STATUS_CHECK_BEGIN_DATE))
				done

				if [ "$HEALTH" == "starting" ]
				then
					echo "  [-] Container is up and not healthy yet"
					RETURN_CODE=1
				elif [ "$HEALTH" == "healthy" ]
				then
					echo "  [+] Container is up and healthy"
				else
					echo "  [-] Container is up and not healthy"
					RETURN_CODE=1
				fi
			else
				echo "  [-] Container is not up"
				RETURN_CODE=1
			fi
		fi
	done

	if [ "$FLAG_CONTAINER" == "0" ]
	then
		echo "-----------------------------------------------------"
		echo "[i] No Bitwarden container found at all"
		echo "The script will be exited"
		exit "$RETURN_CODE"
	fi

	# If at least one container is not up, then restart the bitwarden application
	if [ "$RETURN_CODE" != "0" ]
	then
		echo " -----------------------------------------------------"
		echo " [-] Something was wrong with Bitwarden containers, a restart will be operated"
		echo " -----------------------------------------------------"
		echo " [i] Reboot the Bitwarden application using bitwarden user"
		su - bitwarden -c "$BW_DIR/bitwarden.sh restart"
		RETURN_CODE=$?
	fi

	exit "$RETURN_CODE"
}
main_code > >(tee "$LOG_PATH") 2>&1
RETURN_CODE=$([ $? == 0 ] && echo "$RETURN_CODE" || echo "1")

##################################################################################
exit "$RETURN_CODE"
