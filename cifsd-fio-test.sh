#!/bin/bash


# Sergey Senozhatsky. sergey.senozhatsky@gmail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

#
# Example:
#
# LOG_SUFFIX=NEW FIO_LOOPS=1 ./cifsd-fio-test.sh
#

LOG=/tmp/test-fio-cifsd
EXT_LOG=0
PERF="perf"
FIO="fio"

function reset_cifsd
{
	sudo umount "$MOUNT_POINT"
	sudo killall lt-cifsd
	killall cifsd
	sleep 1s
	sudo rmmod cifsd
}

function create_cifsd
{
	local NET_SHARE="//${HOST}/${SHARE_NAME}"
	local ret

	ret=$(sudo modprobe cifsd)
	if [ "z$ret" != "z" ]; then
		echo "ERROR: CANNOT MODPROBE CIFSD"
		exit 1
	fi

	ret=$(cifsd)
	if [ "z$ret" != "z" ]; then
		echo "ERROR: CANNOT START USER-SPACE DAEMON"
		exit 1
	fi

	sleep 1s

	ret=$(sudo mount -o username=$USER_NAME,password=$USER_PASSWORD,uid=$USER_UID,gid=$USER_GID -t cifs $NET_SHARE $MOUNT_POINT)

	if [ "z$ret" != "z" ]; then
		echo "ERROR: CANNOT MOUNT NETSHARE"
		exit 1
	fi
	return 0
}

function main
{
	local i

	source ./conf/cifsd.conf

	if [ "z$LOG_SUFFIX" == "z" ]; then
		LOG_SUFFIX="UNSET"
	fi

	LOG="$LOG"-"$LOG_SUFFIX"

	if [ "z$MAX_ITER" == "z" ]; then
		MAX_ITER=10
	fi

	if [ "z$MIN_ITER" == "z" ]; then
		MIN_ITER=1
	fi

	if [ "z$FIO_LOOPS" == "z" ]; then
		FIO_LOOPS=1
	fi

	if [ "z$FILE_SIZE" == "z" ]; then
		FILE_SIZE="128M"
	fi

	NOTRACING=""
	if [ "z$NO_TRACING" != "z" ]; then
		NOTRACING="yes"
	fi

	FIO_TEMPLATE=./conf/fio-template-static-buffer
	echo "Using $FIO_TEMPLATE fio template"

	for i in $(seq "$MIN_ITER" "$MAX_ITER"); do
		echo $i

		reset_cifsd
		create_cifsd

		sleep 2s

		if [ "z$NOTRACING" == "z" ]; then
			$(sudo ./tracing-on-off.sh on)
		fi

		if [ $? != 0 ]; then
			echo "Unable to init cifsd"
			exit 1
		fi

		echo "#jobs$i fio"
		echo "#jobs$i fio" >> $LOG

		_NRFILES=1024
		echo "#files $_NRFILES"

		MNT_POINT="$MOUNT_POINT"			\
			SIZE="$FILE_SIZE"			\
			NUMJOBS="$i"				\
			FIO_LOOPS="$FIO_LOOPS"			\
			"$PERF" stat -o "$LOG"-perf-stat	\
			"$FIO" ./"$FIO_TEMPLATE" >> "$LOG"

		if [ "z$NOTRACING" == "z" ]; then
			$(sudo ./tracing-on-off.sh off)
		fi

		echo -n "perfstat jobs$i" >> "$LOG"
		cat "$LOG"-perf-stat >> "$LOG"
	done

	rm "$LOG"-perf-stat
	echo -n "Log files created: $LOG "

	echo
	reset_cifsd
}

main
