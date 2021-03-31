#!/bin/bash

# Auxiliary script to get information on a Docker container
ATTRIBUTE="$1"
CONTAINERNAME="$2"

IFS='%'
# Definition of the exit function
exit_line () {
	local EXITCODE=$1
	unset IFS
	exit "$EXITCODE"
}

# Definition of the function to find in which position the column is written
find_word_position() {
	local WORD="$1"
	shift
	local STRING="$*"
	STRING_SIZE=${#STRING}

	for ((i=1; i<=STRING_SIZE; i++))
	do
		SUBSTRING_CHECK=$(echo "$STRING" | cut -c"$i"- | grep -c "^$WORD ")
		if [ "$SUBSTRING_CHECK" == "1" ]
		then
			echo "$i"
			break;
		fi
	done
}

# Step 1 : Check if the arguments are not empty
if [ "$ATTRIBUTE" == "" ] || [ "$CONTAINERNAME" == "" ]
then
	exit 1
fi

# Step 2 : Check if the attribute is in the docker columns list and find its next column
HAS_COLUMN=0
NEXT_COLUMN=""
DOCKER_COLUMNS=("CONTAINER ID" "IMAGE" "COMMAND" "CREATED" "STATUS" "PORTS" "NAMES")
for ((COLUMN_IDX=0; COLUMN_IDX<${#DOCKER_COLUMNS[@]}; COLUMN_IDX++))
do
	if [ "${DOCKER_COLUMNS[$COLUMN_IDX]}" == "$ATTRIBUTE" ]
	then
		HAS_COLUMN=1
		if [ "$COLUMN_IDX" != "#DOCKER_COLUMNS[@]" ]
		then
			NEXT_COLUMN=${DOCKER_COLUMNS[$COLUMN_IDX+1]}
		fi
	fi
done
if [ "$HAS_COLUMN" != "1" ]
then
	exit 2
fi

# Step 3 : Check of it exists a container with the given name
DOCKER_PS=$(docker ps -a 2>/dev/null)
DOCKER_INFO=$(echo "$DOCKER_PS" | awk -v v_CONTAINERNAME="$CONTAINERNAME" -F' ' '{if($NF==v_CONTAINERNAME){print $0}}' | tail -n1)
if [ "$DOCKER_INFO" == "" ]
then
	exit 3
fi

DOCKER_HEADER=$(echo "$DOCKER_PS" | head -n1)

COLUMN_POS_BEGIN=$(find_word_position "$ATTRIBUTE"   "$DOCKER_HEADER")
if [ "$NEXT_COLUMN" != "" ]
then
	COLUMN_POS_END=$(find_word_position   "$NEXT_COLUMN" "$DOCKER_HEADER")
	COLUMN_POS_END=$((COLUMN_POS_END-1))
fi

echo "$DOCKER_INFO" | cut -c"$COLUMN_POS_BEGIN"-"$COLUMN_POS_END"
exit 0

