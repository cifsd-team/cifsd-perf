#!/bin/sh

cd /sys/kernel/debug/tracing/

if [ "z$1" == "zon" ]; then
	echo ':mod:cifsd' > set_ftrace_filter
	echo 'cifsd*:mod:cifsd' >> set_ftrace_filter
	echo 'smb*:mod:cifsd' >> set_ftrace_filter
	echo function_graph > current_tracer
	echo 1 > tracing_on
else
	echo 0 > tracing_on
	LOG="test-fio-trace"-"$2"
	cat trace >> /tmp/$LOG
fi
