#!/bin/sh
# Copyright (c) 2012-2016 General Electric Company. All rights reserved.
# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

cd "$(dirname "$0")/.."
PREDIX_MACHINE_HOME="$(pwd)"
PREDIX_MACHINE_DATA=${PREDIX_MACHINE_DATA_DIR-$PREDIX_MACHINE_HOME}
START_PREDIX_MACHINE_LOG=$PREDIX_MACHINE_DATA/logs/machine/start_predixmachine.log
# The Airsync directory where JSON files are picked up.
AIRSYNC=$PREDIX_MACHINE_DATA/appdata/airsync

# This function takes a string value, creates a timestamp, and writes it the log file as well as the console
writeConsoleLog () {
    echo "$(date +"%m/%d/%y %H:%M:%S") $1"
    if [ "x$START_PREDIX_MACHINE_LOG" != "x" ]; then
       echo "$(date +"%m/%d/%y %H:%M:%S") $1" >> "$START_PREDIX_MACHINE_LOG"
    fi
}

# This function cleans up after a failed install by removing the downloaded zip and temporary files.
installFailed () {
	# Copy the sig file to the yeti appdata folder to trigger the installation log post
	cp "$zip.sig" "$PF_APPDATA"
	rm "$zip"
	rm "$zip.sig"
	rm -rf "$TEMPDIR"
	writeConsoleLog "$message"
	echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$START_PREDIX_MACHINE_LOG"
	echo "$(date +"%m/%d/%y %H:%M:%S") #                           Installation failed.                         #">> "$START_PREDIX_MACHINE_LOG"
	echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$START_PREDIX_MACHINE_LOG"
}

installSuccess () {
	writeConsoleLog "Installation of $unzipDir was successful."
	echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$START_PREDIX_MACHINE_LOG"
	echo "$(date +"%m/%d/%y %H:%M:%S") #                         Installation successful                        #">> "$START_PREDIX_MACHINE_LOG"
	echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$START_PREDIX_MACHINE_LOG"
	# Copy the sig file to the yeti appdata folder to trigger the installation log post
	cp "$zip.sig" "$PF_APPDATA"
	rm "$zip"
	rm "$zip.sig"
	rm -rf "$TEMPDIR"
}

# This function writes a JSON to the appdata/airsync directory to indicate installation failure
writeFailureJSON () {
	printf "{\n\t\"status\" : \"failure\",\n\t\"errorcode\" : $errorcode,\n\t\"message\" : \"$message\"\n}\n" > "$PREDIX_MACHINE_DATA/appdata/airsync/$unzipDir.json"
}

# This function is used as a trap in case the process is attempted to be closed during an install
installInProgress () {
	writeConsoleLog "Installation in progress.  Yeti will shut down after installation completes."
}

# This function monitors the JSON file produced by an installation for it to be picked up by the Airsync service
# If the file is removed by the service, the cloud connection is confirmed.  If not we assume the container
# could not reconnect and rollback the update.
checkConnection () {
	CONNCHECKCNT=0
	CONFIGCOUNT=$(grep -E "^rollbackWaitDuration[\s]*=[\s]*[^\s]+" "$PREDIX_MACHINE_HOME/configuration/yeti/yeti.cfg")
	if [ $? -eq 0 ]; then
		MAXCONNCNT=$(echo $CONFIGCOUNT | cut -d '=' -f 2)
		case $MAXCONNCNT in
		   (*[!0-9]*|'') writeConsoleLog "rollbackWaitDuration is not an integer or is negative. Defaulting to 60."
		   				 MAXCONNCNT=60
		   				 ;;
		   (*)  		 writeConsoleLog "rollbackWaitDuration is $MAXCONNCNT";;
		esac
	else
		MAXCONNCNT=60
	fi
	while true; do
		if [ "$CONNCHECKCNT" -ge "$MAXCONNCNT" ]; then
			writeConsoleLog "Error: Predix Machine did not reconnect to cloud after update. Rolling back update."
			writeConsoleLog "Installation of $unzipDir was unsuccessful."
			errorcode="52"
			message="Predix Machine did not reconnect to cloud after $unzipDir installation. Error Code: $errorcode"
			rollback
			writeFailureJSON
			installFailed
			break
		elif [ -f "$AIRSYNC/$unzipDir.json" ]; then
			writeConsoleLog "Checking for connection to cloud..."
			sleep 10
			CONNCHECKCNT=$((CONNCHECKCNT+1))
		else
			writeConsoleLog "Connection to cloud was successful."
			installSuccess
			break
		fi
	done
}

# This function is to rollback the previous installation upon failed install.
rollback () {
	echo "Cloud connection failed after installation. Attempting rollback." >> "$LOGNAME"
	newapp=${appname##*/}
	if [ -d "$PREDIX_MACHINE_DATA/$newapp.old" ]; then
		sh "$PREDIX_MACHINE_DATA/yeti/watchdog/stop_watchdog.sh"
		rm -rvf "$PREDIX_MACHINE_DATA/$newapp" >> "$LOGNAME" 2>&1
		mv -v "$PREDIX_MACHINE_DATA/$newapp.old/" "$PREDIX_MACHINE_DATA/$newapp/" >> "$LOGNAME" 2>&1
		if [ $? -eq 0 ]; then
			writeConsoleLog "Rollback successful."
			message="$message. Rollback successful."
		else
			writeConsoleLog "Rollback unsuccessful."
			message="$message. Rollback unsuccessful."
		fi
		echo $message >> "$LOGNAME"
		sh "$PREDIX_MACHINE_DATA/yeti/watchdog/start_watchdog.sh" &
	fi
}

# This function is used as an exit trap to ensure the framework is shutdown and clean up and stop signals.
finish () {
	# Check for the yeti stop signal
	writeConsoleLog "Yeti is shutting down."
	sh "$PREDIX_MACHINE_DATA/yeti/watchdog/stop_watchdog.sh"
	if [ -d "$TEMPDIR" ]; then
		rm -rf "$TEMPDIR"
	fi
	if [ -f "$YETI_STOP_SIGNAL" ]; then
		rm "$YETI_STOP_SIGNAL"
	fi
	writeConsoleLog "Shutdown complete."
	exit 0
} # Don't trap on exit because finish() calls exit. This creates a loop.
trap finish INT TERM

# SCRIPT ACTUALLY STARTS HERE. ALL THAT CAME BEFORE ARE FUNCTIONS.

# The validate start script checks for the java keytool and that no other containers are running
sh "$PREDIX_MACHINE_HOME/machine/bin/predix/validate_start.sh"
if [ $? -ne 0 ]; then
    exit 1
fi
rm -f "$YETI_STOP_SIGNAL"
# Checks the directory structure for the watchdog, which is required for updates.
if [ ! -f "$PREDIX_MACHINE_DATA/yeti/watchdog/start_watchdog.sh" ]; then
	writeConsoleLog "The watchdog does not exist at $PREDIX_MACHINE_DATA/yeti/watchdog.  This is required for Yeti."
	exit 1
fi

PF_APPDATA=$PREDIX_MACHINE_DATA/appdata/packageframework
if [ ! -d "$PF_APPDATA" ]; then
	mkdir "$PF_APPDATA"
fi

echo "$(date +"%m/%d/%y %H:%M:%S") $(date)" > "$START_PREDIX_MACHINE_LOG"
writeConsoleLog "Yeti started..."

# Take care of permissions for an unzip
chmod +x "$PREDIX_MACHINE_DATA/yeti/watchdog/start_watchdog.sh" > "$START_PREDIX_MACHINE_LOG" 2>&1
chmod +x "$PREDIX_MACHINE_DATA/yeti/watchdog/stop_watchdog.sh" > "$START_PREDIX_MACHINE_LOG" 2>&1
chmod +x "$PREDIX_MACHINE_HOME/machine/bin/predix/start_container.sh" > "$START_PREDIX_MACHINE_LOG" 2>&1
chmod +x "$PREDIX_MACHINE_HOME/machine/bin/predix/stop_container.sh" > "$START_PREDIX_MACHINE_LOG" 2>&1
chmod +x "$PREDIX_MACHINE_HOME/machine/bin/predix/validate_start.sh" > "$START_PREDIX_MACHINE_LOG" 2>&1

# Cleanup and setup for Yeti
# Cleanup any old temporary directories and create a new one.
rm -rf /tmp/tempdir.$$
(umask 077 && mkdir /tmp/tempdir.$$) || code=$?
if [ "$code" != "0" ] && [ "$code" != "" ]; then
	writeConsoleLog "Error creating temporary directory. Error: $code"
	exit 1
fi

# Check the environment for the PREDIXMACHINELOCK variable.  If not set use the security directory.
if [ ! -n "${PREDIXMACHINELOCK+1}" ]; then
	PREDIXMACHINELOCK=$PREDIX_MACHINE_DATA/security
fi

# The stop signal is used to indicate the Yeti loop should exit.
YETI_STOP_SIGNAL=$PREDIXMACHINELOCK/stop_yeti
WATCHDOG_STOP_SIGNAL=$PREDIXMACHINELOCK/stop_watchdog
# Cleanup old stop signals
rm -f "$YETI_STOP_SIGNAL"
rm -f "$WATCHDOG_STOP_SIGNAL"

# Startup watchdog
sh "$PREDIX_MACHINE_DATA/yeti/watchdog/start_watchdog.sh" &

writeConsoleLog "Watchdog started, ready to install new packages."
TEMPDIR="/tmp/tempdir.$$"
while [ ! -f "$YETI_STOP_SIGNAL" ]; do
	trap finish INT TERM
	# Check the installations directory for new package files.
	zips=$(ls "${PREDIX_MACHINE_DATA}"/installations/*.zip 2> /dev/null)
	if [ "$zips" != "" ]; then
        for zip in "${PREDIX_MACHINE_DATA}"/installations/*.zip; do
			# Verify the zip
			# Change the trap to install in progress so Yeti doesn't exit in the middle of an install
			trap installInProgress INT TERM
			unzipDir=$(basename "$zip")
			unzipDir="${unzipDir%.*}"
			if [ -d "$TEMPDIR" ]; then
				rm -rf "$TEMPDIR"
			fi
			# Wait for the associated zip.sig file to be present.  Each package should have this, it is required for verification.
			waitcnt=0
			while [ $waitcnt -lt 12 ] && [ ! -f "$zip.sig" ]; do
				waitcnt=$((waitcnt+1))
				sleep 5
			done
			if [ $waitcnt -eq 12 ]; then
				message="No signature file found for associated zip. Package origin could not be verified."
				errorcode="21"
				writeFailureJSON
				installFailed
				continue
			fi
			mkdir "$TEMPDIR"
			cd "$TEMPDIR"
			# Run the verification process using the package.zip and package.zip.sig
			java -jar "${PREDIX_MACHINE_DATA}"/yeti/com.ge.dspmicro.yetiappsignature-16.4.3.jar "${PREDIX_MACHINE_DATA}" "$zip">>"$START_PREDIX_MACHINE_LOG" 2>&1
			if [ $? -ne 0 ]; then
				message="Package origin was not verified to be from the Predix Cloud. Installation failed"
				errorcode="22"
				writeFailureJSON
				installFailed
				continue
			else
				writeConsoleLog "Package origin has been verified. Continuing installation."
			fi
			cd "$PREDIX_MACHINE_DATA"
			# Yeti only supports a single directory per installation zip, count the number of directories
			cnt=0
			for app in "$TEMPDIR"/*; do
				appname="$app"
				cnt=$((cnt+1))
			done
			# Applications can have an install script at the top level or directly in the application directory
			if [ "$cnt" -ne 1 ] || [ ! -f "$appname/install/install.sh" ] && [ ! -f "$TEMPDIR/install/install.sh" ]; then
				message="Incorrect zip format.  Applications should be a single folder with the packagename/install/install.sh structure, zipped with unix zip utility."
				errorcode="24"
				writeFailureJSON
				installFailed
				continue
			fi
			writeConsoleLog "Running the $unzipDir install script..."
			echo "startTimestamp="$(date +%s) > "$PF_APPDATA/$unzipDir.properties"
			LOGNAME=$PREDIX_MACHINE_DATA/logs/installations/$unzipDir.log
			# Store standard out in 6 to redirect std out to the log file
			exec 8>&1
			exec 9>&2
			exec >> "$LOGNAME"
			exec 2>> "$LOGNAME"
			# Std out and error are redirected in the watchdog script
			if [ -f "$TEMPDIR/install/install.sh" ]; then
				sh "$TEMPDIR/install/install.sh" "$PREDIX_MACHINE_DATA" "$TEMPDIR" "$unzipDir"
			else
				sh "$appname/install/install.sh" "$PREDIX_MACHINE_DATA" "$TEMPDIR" "$unzipDir"
			fi
			# Errorcode is the return value from the install script
			errorcode=$?
			# Check if file descriptor 6 is open, redirect output back to std out and close the descriptor
			if [ -e /dev/fd/8 ]; then
				exec 1>&8 8>&-
			fi
			if [ -e /dev/fd/9 ]; then
				exec 2>&9 9>&-
			fi
			echo "endTimestamp="$(date +%s) >> "$PF_APPDATA/$unzipDir.properties"
			if [ $errorcode -eq 100 ]; then
				# Error code 100 used to skip yeti checks for success, only to be used when certain package will succeed.
				installSuccess
				continue
			fi
			if [ $errorcode -ne 0 ] && [ -f "$AIRSYNC/$unzipDir.json" ]; then
				message="Installation of $unzipDir failed. Error Code: $errorcode"
				installFailed
				continue
			fi
			if [ $errorcode -ne 0 ]; then
				message="An error occurred while running the install script. Error Code: $errorcode"
				writeFailureJSON
				installFailed
				continue
			fi
			if [ ! -f "$AIRSYNC/$unzipDir.json" ]; then
				errorcode="53"
				message="An error occurred while running the install script. The $unzipDir installation script did not produce a JSON result to verify its completion. Error Code: $errorcode"
				writeFailureJSON
				installFailed
				continue
			fi
			# Need to check for successful connection to cloud
			checkConnection
		done
		writeConsoleLog "Done."
	else
		sleep 5
	fi
done
finish