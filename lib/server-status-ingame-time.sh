#!/bin/bash

SERVER_STATUS_LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SERVER_STATUS_LIB_DIR/server-status-common.sh"

server_status_log_epoch() {
	local line="${1:-}"
	if [[ "$line" =~ ([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})[[:space:]]([0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
		local log_date="${BASH_REMATCH[3]}-${BASH_REMATCH[1]}-${BASH_REMATCH[2]} ${BASH_REMATCH[4]}"
		local log_epoch
		log_epoch=$(LC_ALL=C date -d "$log_date" +%s.%N 2>/dev/null) || log_epoch=""
		if [ -n "$log_epoch" ]; then
			printf '%s\n' "$log_epoch"
			return 0
		fi
	fi
	date +%s.%N
}

server_status_project_ingame_time() {
	local sample_time="${1//,/.}"
	local sample_day="$2"
	local sample_epoch="$3"
	local now_epoch="$4"
	local advance_clock="${5:-1}"

	LC_ALL=C awk -v sample_time="$sample_time" -v sample_day="$sample_day" -v sample_epoch="$sample_epoch" -v now_epoch="$now_epoch" -v advance_clock="$advance_clock" '
		function day_index(time_value, index_value) {
			index_value = (time_value - 270) / 1800
			return index_value < int(index_value) ? int(index_value) - 1 : int(index_value)
		}
		BEGIN {
			elapsed = now_epoch - sample_epoch
			if (!advance_clock) elapsed = 0
			if (elapsed < 0) exit
			estimated_time = sample_time + elapsed * 48
			current_day = sample_day + day_index(estimated_time) - day_index(sample_time)
			day_phase = estimated_time - int(estimated_time / 1800) * 1800
			if (day_phase < 0) day_phase += 1800
			game_clock_seconds = day_phase * 48
			hour = int(game_clock_seconds / 3600)
			minute = int((game_clock_seconds - hour * 3600) / 60)
			printf "%d|%.9f|%02d:%02d", current_day, estimated_time, hour, minute
		}'
	}

server_status_update_ingame_sample() {
	local now_epoch="${1:-$(date +%s.%N)}"
	local advance_clock="${2:-1}"
	INGAMETIMEFILE="${INGAMETIMEFILE:-$STATUS_ROOT/data/ingame-time}"
	[ -r "$INGAMETIMEFILE" ] || return 1
	local sample_time sample_day sample_epoch
	IFS=';' read -r sample_time sample_day sample_epoch < "$INGAMETIMEFILE"
	if [[ ! "$sample_time" =~ ^[0-9]+([.,][0-9]+)?$ || ! "$sample_day" =~ ^[0-9]+$ || ! "$sample_epoch" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		return 1
	fi
	local estimate
	estimate=$(server_status_project_ingame_time "$sample_time" "$sample_day" "$sample_epoch" "$now_epoch" "$advance_clock")
	[ -n "$estimate" ] || return 1
	local updated_day updated_time display_time
	IFS='|' read -r updated_day updated_time display_time <<< "$estimate"
	printf '%s;%s;%s\n' "$updated_time" "$updated_day" "$now_epoch" > "$INGAMETIMEFILE"
}

server_status_calculate_ingame_clock() {
	INGAMETIMEFILE="${INGAMETIMEFILE:-$STATUS_ROOT/data/ingame-time}"
	INGAME_TIME_LABEL="unknown"
	CURRENT_INGAMEDAYNUMBER="unknown"
	if [ -n "$VALHEIM_PID" ] && [ -r "$INGAMETIMEFILE" ]; then
		IFS=';' read -r SAMPLE_TIME SAMPLE_DAY SAMPLE_EPOCH < "$INGAMETIMEFILE"
		if [[ "$SAMPLE_TIME" =~ ^[0-9]+([.,][0-9]+)?$ && "$SAMPLE_DAY" =~ ^[0-9]+$ && "$SAMPLE_EPOCH" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
			SAMPLE_TIME="${SAMPLE_TIME//,/.}"
			NOW_EPOCH=$(date +%s.%N)
			HAS_CONNECTED_PLAYERS=$(awk -F';' 'NF >= 3 && $2 != "" { print 1; exit }' "$CONNECTEDPLAYERSFILE" 2>/dev/null)
			HAS_CONNECTED_PLAYERS="${HAS_CONNECTED_PLAYERS:-0}"
			INGAME_STATUS=$(server_status_project_ingame_time "$SAMPLE_TIME" "$SAMPLE_DAY" "$SAMPLE_EPOCH" "$NOW_EPOCH" "$HAS_CONNECTED_PLAYERS")
			if [ -n "$INGAME_STATUS" ]; then
				IFS='|' read -r CURRENT_INGAMEDAYNUMBER ESTIMATED_INGAME_TIME INGAME_TIME_LABEL <<< "$INGAME_STATUS"
			fi
		fi
	fi
}

server_status_prepare_weather() {
	WEATHERFORECAST_VALUE="unknown"
	if [[ "$CURRENT_INGAMEDAYNUMBER" =~ ^[0-9]+$ ]]; then
		WEATHERFORECASTURLBASE="${WEATHERFORECASTURLBASE:-${WEATHERFORECASTURL%%#*}#}"
		WEATHERFORECASTURL="${WEATHERFORECASTURLBASE}${CURRENT_INGAMEDAYNUMBER}"
		WEATHERFORECAST_VALUE="[Link](${WEATHERFORECASTURL})"
	fi
}