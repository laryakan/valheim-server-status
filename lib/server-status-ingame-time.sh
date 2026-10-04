#!/bin/bash

LIBDIR="${LIBDIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )}"
source "$LIBDIR/server-status-common.sh"

server_status_log_epoch() {
	local line="${1:-}"
	if [[ "$line" =~ ([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})[[:space:]]([0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
		date -d "${BASH_REMATCH[3]}-${BASH_REMATCH[1]}-${BASH_REMATCH[2]} ${BASH_REMATCH[4]}" +%s.%N 2>/dev/null && return 0
	fi
	date +%s.%N
}

server_status_active_elapsed() {
	local sample_epoch="$1"
	local now_epoch="$2"
	local has_players="$3"
	local events_file="${INGAMETIMEEVENTSFILE:-$VSSDIR/data/ingame-time-events}"
	local active=0 active_since=0 total=0 event_type event_line event_epoch

	if [ -r "$events_file" ]; then
		while IFS='|' read -r event_type event_line; do
			event_epoch=$(server_status_log_epoch "$event_line")
			case "$event_type" in
				active)
					active=1
					active_since="$event_epoch"
					;;
				paused)
					if [ "$active" -eq 1 ] && awk -v start="$active_since" -v end="$event_epoch" 'BEGIN { exit !(end >= start) }'; then
						total=$(awk -v total="$total" -v start="$active_since" -v end="$event_epoch" 'BEGIN { printf "%.9f", total + end - start }')
					fi
					active=0
					;;
			esac
		done < "$events_file"
	elif [ "$has_players" -eq 1 ]; then
		active=1
		active_since="$sample_epoch"
	fi

	if [ "$active" -eq 1 ] && [ "$has_players" -eq 1 ] && awk -v start="$active_since" -v end="$now_epoch" 'BEGIN { exit !(end >= start) }'; then
		total=$(awk -v total="$total" -v start="$active_since" -v end="$now_epoch" 'BEGIN { printf "%.9f", total + end - start }')
	fi
	printf '%s\n' "$total"
}

server_status_project_ingame_time() {
	local sample_time="${1//,/.}"
	local sample_day="$2"
	local active_seconds="$3"

	LC_ALL=C awk -v sample_time="$sample_time" -v sample_day="$sample_day" -v active_seconds="$active_seconds" '
		function day_index(time_value, index_value) {
			index_value = (time_value - 270) / 1800
			return index_value < int(index_value) ? int(index_value) - 1 : int(index_value)
		}
		BEGIN {
			estimated_time = sample_time + active_seconds
			current_day = sample_day + day_index(estimated_time) - day_index(sample_time)
			day_phase = estimated_time - int(estimated_time / 1800) * 1800
			if (day_phase < 0) day_phase += 1800
			game_clock_seconds = day_phase * 48
			hour = int(game_clock_seconds / 3600)
			minute = int((game_clock_seconds - hour * 3600) / 60)
			sky = game_clock_seconds >= 12960 && game_clock_seconds <= 73440 ? "☀️" : "🌙"
			printf "%d|%.9f|%s %02d:%02d", current_day, estimated_time, sky, hour, minute
		}'
	}

server_status_calculate_ingame_clock() {
	INGAMETIMEFILE="${INGAMETIMEFILE:-$VSSDIR/data/ingame-time}"
	INGAMETIMEEVENTSFILE="${INGAMETIMEEVENTSFILE:-$VSSDIR/data/ingame-time-events}"
	INGAME_TIME_LABEL="unknown"
	CURRENT_INGAMEDAYNUMBER="unknown"
	if [ -n "$VALHEIM_PID" ] && [ -r "$INGAMETIMEFILE" ]; then
		IFS= read -r SAMPLE_LINE < "$INGAMETIMEFILE"
		if [[ "$SAMPLE_LINE" =~ Time[[:space:]]+[0-9]+([,.][0-9]+)?,?[[:space:]]+day[[:space:]]*:[[:space:]]*([0-9]+).*nextm[[:space:]]*:[[:space:]]*([0-9]+([,.][0-9]+)?|[0-9]+) ]]; then
			SAMPLE_DAY="${BASH_REMATCH[2]}"
			SAMPLE_TIME="${BASH_REMATCH[3]//,/.}"
			SAMPLE_EPOCH=$(server_status_log_epoch "$SAMPLE_LINE")
			NOW_EPOCH=$(date +%s.%N)
			HAS_CONNECTED_PLAYERS=$(awk -F';' 'NF >= 3 && $2 != "" { print 1; exit }' "$CONNECTEDPLAYERSFILE" 2>/dev/null)
			HAS_CONNECTED_PLAYERS="${HAS_CONNECTED_PLAYERS:-0}"
			ACTIVE_ELAPSED=$(server_status_active_elapsed "$SAMPLE_EPOCH" "$NOW_EPOCH" "$HAS_CONNECTED_PLAYERS")
			INGAME_STATUS=$(server_status_project_ingame_time "$SAMPLE_TIME" "$SAMPLE_DAY" "$ACTIVE_ELAPSED")
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