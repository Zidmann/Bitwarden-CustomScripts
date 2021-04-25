#!/bin/bash

# Auxiliary script to get information on a Docker container
ATTRIBUTE="$1"
CONTAINERNAME="$2"

# Commands

case "$ATTRIBUTE" in
	"HEALTH")
		FORMAT="{{.State.Health.Status}}"
		;;
	"STATUS")
		FORMAT="{{.State.Status}}"
		;;
	"IMAGE")
		FORMAT="{{.Config.Image}}"
		;;
	*)
		exit 0
		;;
esac

docker inspect --format="$FORMAT" "$CONTAINERNAME"
exit 0

