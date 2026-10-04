#!/bin/bash

SERVER_STATUS_LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SERVER_STATUS_LIB_DIR/server-status-common.sh"

server_status_calculate_ingame_clock() {
	INGAMETIMEFILE="${INGAMETIMEFILE:-$STATUS_ROOT/data/ingame-time}"
	INGAME_TIME_LABEL="unknown"
	CURRENT_INGAMEDAYNUMBER="unknown"
	if [ -n "$VALHEIM_PID" ] && [ -r "$INGAMETIMEFILE" ]; then
		IFS=';' read -r SAMPLE_TIME SAMPLE_DAY NEXTM_TIME SKIPSPEED SAMPLE_EPOCH < "$INGAMETIMEFILE"
		if [[ "$SAMPLE_TIME" =~ ^[0-9]+([.,][0-9]+)?$ && "$SAMPLE_DAY" =~ ^[0-9]+$ && "$NEXTM_TIME" =~ ^[0-9]+([.,][0-9]+)?$ && "$SKIPSPEED" =~ ^[0-9]+([.,][0-9]+)?$ && "$SAMPLE_EPOCH" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
			SAMPLE_TIME="${SAMPLE_TIME//,/.}"
			NEXTM_TIME="${NEXTM_TIME//,/.}"
			SKIPSPEED="${SKIPSPEED//,/.}"
			NOW_EPOCH=$(date +%s.%N)
			PROCESS_START_EPOCH=$(date -d "${PROCESS_START_RAW:-}" +%s.%N 2>/dev/null || echo 0)
			HAS_CONNECTED_PLAYERS=$(awk -F';' 'NF >= 3 && $2 != "" { print 1; exit }' "$CONNECTEDPLAYERSFILE" 2>/dev/null)
			HAS_CONNECTED_PLAYERS="${HAS_CONNECTED_PLAYERS:-0}"
			INGAME_STATUS=$(awk -v sample_time="$SAMPLE_TIME" -v sample_day="$SAMPLE_DAY" -v nextm_time="$NEXTM_TIME" -v skipspeed="$SKIPSPEED" -v sample_epoch="$SAMPLE_EPOCH" -v now_epoch="$NOW_EPOCH" -v process_start_epoch="$PROCESS_START_EPOCH" -v has_connected_players="$HAS_CONNECTED_PLAYERS" '
				BEGIN {
					anchor_epoch = sample_epoch
					if (process_start_epoch > anchor_epoch) anchor_epoch = process_start_epoch
					elapsed = now_epoch - anchor_epoch
					if (!has_connected_players) elapsed = 0
					if (elapsed < 0 || skipspeed <= 0 || nextm_time < sample_time) exit
					time_to_nextm = (nextm_time - sample_time) / skipspeed
					if (elapsed <= time_to_nextm) {
						estimated_time = sample_time + elapsed * skipspeed
						current_day = sample_day
					} else {
						after_nextm = elapsed - time_to_nextm
						estimated_time = nextm_time + after_nextm
						current_day = sample_day + 1 + int(after_nextm / 1800)
					}
					day_phase = estimated_time - int(estimated_time / 1800) * 1800
					if (day_phase < 0) day_phase += 1800
					game_clock_seconds = day_phase * 48
					hour = int(game_clock_seconds / 3600)
					minute = int((game_clock_seconds - hour * 3600) / 60)
					printf "%d|%02d:%02d", current_day, hour, minute
				}'
			)
			if [ -n "$INGAME_STATUS" ]; then
				IFS='|' read -r CURRENT_INGAMEDAYNUMBER INGAME_TIME_LABEL <<< "$INGAME_STATUS"
			fi
		fi
	fi
}

server_status_prepare_weather() {
	WEATHERFORECAST_VALUE="unknown"
	if [[ "$CURRENT_INGAMEDAYNUMBER" =~ ^[0-9]+$ ]]; then
		WEATHERFORECASTURLBASE="${WEATHERFORECASTURLBASE:-${WEATHERFORECASTURL%%#*}#}"
		WEATHERFORECASTURL="${WEATHERFORECASTURLBASE}${CURRENT_INGAMEDAYNUMBER}"
		WEATHERFORECAST_VALUE="[${WEATHERFORECASTURL}](${WEATHERFORECASTURL})"
	fi
}