#!/bin/bash

LIBDIR="${LIBDIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )}"
source "$LIBDIR/server-status-common.sh"

server_status_collect_process_stats() {
	TOTALCPU=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
	TOTALCPU=$(( TOTALCPU > 0 ? TOTALCPU : 1 ))
	TOTALRAM=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | cut -d' ' -f9 || echo 0) / 1024 ))

	VALHEIM_PID="${VALSERVERPID:-}"
	if [ -n "$VALHEIM_PID" ] && ps -p "$VALHEIM_PID" >/dev/null 2>&1
	then
		:
	else
		VALHEIM_PID=$(pgrep -f 'valheim_server' 2>/dev/null | head -n 1)
	fi

	PROCESS_START_RAW=""
	if [ -n "$VALHEIM_PID" ]
	then
		PS_OUTPUT=$(LC_ALL=C ps -p "$VALHEIM_PID" -o lstart=,%cpu=,%mem= --no-headers 2>/dev/null | head -n 1)
		if [ -n "$PS_OUTPUT" ]
		then
			read -r START_DAY START_MONTH START_DAYNUM START_TIME START_YEAR CPUUSAGE_RAW RAMUSAGE_RAW <<EOF
$PS_OUTPUT
EOF
			PROCESS_START_RAW="${START_DAY} ${START_MONTH} ${START_DAYNUM} ${START_TIME} ${START_YEAR}"
			PROCESS_START_TS=$(date -d "$PROCESS_START_RAW" '+%d/%m/%Y %H:%M:%S' 2>/dev/null || true)
			CPUUSAGE=$(printf '%s' "$CPUUSAGE_RAW" | tr ',' '.' | awk '{printf "%.0f", $1}')
			RAMUSAGE=$(printf '%s' "$RAMUSAGE_RAW" | tr ',' '.' | awk '{printf "%.0f", $1}')
		else
			PROCESS_START_TS="unknown"
			CPUUSAGE=0
			RAMUSAGE=0
		fi
		if [ "$TOTALCPU" -gt 0 ]
		then
			CPUUSAGE=$(( CPUUSAGE / TOTALCPU ))
		fi
	else
		PROCESS_START_TS="unknown"
		CPUUSAGE=0
		RAMUSAGE=0
	fi
}