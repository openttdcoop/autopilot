#!/bin/bash

function check_pid ()
{
	# file exists?
	if [ -f "$AP_FILE_PID" ]; then
		local PID="`cat "$AP_FILE_PID"`"
	else
		rm "$AP_FILE_PID"
		return 1
	fi

	# if pid is empty, remove it
	if [ -z "$PID" ]; then
		rm "$AP_FILE_PID"
		return 2
	fi

	# test pid exists
	if [ -z "`ps h -p $PID` 2&>1 > /dev/null" ]; then
		rm "$AP_FILE_PID"
		return 3
	fi

	# if we get here, all is fine
	AP_PID=$PID
}


GAME_DIR="`cd $GAME_DIR/.. && pwd`"

AP_DIR="$GAME_DIR/autopilot"
AP_DIR_BIN="$AP_DIR/bin"

AP_FILE_PID="$GAME_DIR/autopilot.pid"
AP_FILE_CMD="$AP_DIR/custom_cmd"
AP_FILE_MSG="$AP_DIR/custom_chat"

AP_PID=""
check_pid

OTTD_SAV="$GAME_DIR/save"
OTTD_BIN="$GAME_DIR/openttd"
