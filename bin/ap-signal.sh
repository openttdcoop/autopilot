#!/bin/bash

GAME_DIR="`dirname $0`"

source $GAME_DIR/ap-env.sh

SIG=$1

if [ $# -lt 1 ]; then
	echo "USAGE $0 <signal>"
	echo "  signal     the signal is mapped to a proper kill signal,"
	echo "             please amend the mapping in this script as needed"
	exit 1
fi

if [ -z "$AP_PID" ]; then
	echo $AP_PID
	echo "Autopilot is not running"
	exit 1
fi

case $SIG in
	SCHED_QUIT)
		SIGNAL="QUIT"
		;;
	USER_QUIT)
		SIGNAL="TERM"
		;;
	SAVE)
		SIGNAL="POLL"
		;;
	CHAT)
		SIGNAL="ALRM"
		;;
	COMMAND)
		SIGNAL="PROF"
		;;
	PAUSE)
		SIGNAL="USR1"
		;;
	UNPAUS)
		SIGNAL="USR2"
		;;
	REHASH)
		SIGNAL="HUP"
		;;
	IRC_QUIT)
		SIGNAL="ABRT"
		;;
	IRC_JOIN)
		SIGNAL="CONT"
		;;
esac

if [ -z "$SIGNAL" ]; then
	echo "unknown signal"
	exit 2
fi

kill -s $SIGNAL $AP_PID
