#!/bin/bash
set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/data" "$TEMP_DIR/logs" "$TEMP_DIR/status" "$TEMP_DIR/launcher" "$TEMP_DIR/lib"
cp "$ROOT_DIR/vss.log-filter" "$TEMP_DIR/vss.log-filter"
cp "$ROOT_DIR/status/server-status" "$TEMP_DIR/status/server-status"
cp "$ROOT_DIR"/lib/server-status-*.sh "$TEMP_DIR/lib/"
cp "$ROOT_DIR/i18n.sh" "$TEMP_DIR/i18n.sh"
printf '\n' > "$TEMP_DIR/launcher/launcher-args"

cat > "$TEMP_DIR/.env" <<EOF
set -o allexport
VSSDIR="$TEMP_DIR"
DEBUGMODE=0
EVENTREALTIME=0
VALHEIMSERVERLOGDIR="$TEMP_DIR/logs"
CONNECTEDPLAYERSFILE="$TEMP_DIR/data/online-players"
OFFLINEPLAYERSFILE="$TEMP_DIR/data/offline-players"
STEAMIDMAPFILE="$TEMP_DIR/data/steamid-player-map"
LASTWORLDSAVEFILE="$TEMP_DIR/data/last-world-save"
INGAMETIMEFILE="$TEMP_DIR/data/ingame-time"
VALSERVERPID="$PPID"
VALSERVERVERSION="1.0"
VALSERVERLASTUPDATE="unknown"
VSSBEPINEXENABLED=0
VHSERVERSEED="test-seed"
VHSERVERWORLD="test-world"
VSS_LANG=en
WEATHERFORECASTURLBASE="https://example.invalid/weather#"
set +o allexport
EOF

for module in "$TEMP_DIR"/lib/server-status-*.sh; do
  STATUS_ROOT="$TEMP_DIR" bash -c 'source "$1"; declare -F T >/dev/null; [[ "${VSS_STATUS_ENV_LOADED:-0}" == 1 && "${VSS_STATUS_I18N_LOADED:-0}" == 1 ]]' _ "$module"
done

STATUS_ROOT="$TEMP_DIR"
source "$TEMP_DIR/lib/server-status-ingame-time.sh"
BOUNDARY_EPOCH=$(date +%s.%N)
[[ "$(server_status_project_ingame_time 270 1 "$BOUNDARY_EPOCH" "$BOUNDARY_EPOCH" 0)" == *'|☀️ 03:36' ]]
[[ "$(server_status_project_ingame_time 1530 1 "$BOUNDARY_EPOCH" "$BOUNDARY_EPOCH" 0)" == *'|☀️ 20:24' ]]
[[ "$(server_status_project_ingame_time 1531.25 1 "$BOUNDARY_EPOCH" "$BOUNDARY_EPOCH" 0)" == *'|🌙 20:25' ]]
[[ "$(server_status_project_ingame_time 269.979166667 1 "$BOUNDARY_EPOCH" "$BOUNDARY_EPOCH" 0)" == *'|🌙 03:35' ]]

printf '%s\n' \
  'Time 795831,77718268, day:441 nextm:795870,000010729 skipspeed:3,18523567076772' \
  | VSSDIR= "$TEMP_DIR/vss.log-filter"

IFS=';' read -r SAMPLE_TIME SAMPLE_DAY SAMPLE_EPOCH < "$TEMP_DIR/data/ingame-time"
[[ "$SAMPLE_TIME" == "795831.77718268" ]]
[[ "$SAMPLE_DAY" == "441" ]]
[[ "$SAMPLE_EPOCH" =~ ^[0-9]+\.[0-9]{9}$ ]]

LOG_TIMESTAMP=$(date '+%m/%d/%Y %H:%M:%S')
IFS='/ :' read -r LOG_MONTH LOG_DAY LOG_YEAR LOG_HOUR LOG_MINUTE LOG_SECOND <<< "$LOG_TIMESTAMP"
EXPECTED_LOG_EPOCH=$(date -d "$LOG_YEAR-$LOG_MONTH-$LOG_DAY $LOG_HOUR:$LOG_MINUTE:$LOG_SECOND" +%s.%N)
printf '%s\n' "$LOG_TIMESTAMP: Time 795831,77718268, day:441 nextm:795870,000010729 skipspeed:3,18523567076772" \
  | VSSDIR= "$TEMP_DIR/vss.log-filter"
IFS=';' read -r SAMPLE_TIME SAMPLE_DAY SAMPLE_EPOCH < "$TEMP_DIR/data/ingame-time"
[[ "$SAMPLE_EPOCH" == "$EXPECTED_LOG_EPOCH" ]]

SAMPLE_EPOCH=$(awk -v now="$(date +%s.%N)" 'BEGIN { printf "%.9f", now - 1 }')
printf '%s;%s;%s\n' "$SAMPLE_TIME" "$SAMPLE_DAY" "$SAMPLE_EPOCH" > "$TEMP_DIR/data/ingame-time"
touch "$TEMP_DIR/data/online-players" "$TEMP_DIR/data/offline-players" "$TEMP_DIR/data/last-world-save"
printf '2026-10-04.00:00:00;test-player;1:1\n' > "$TEMP_DIR/data/online-players"

STATUS_OUTPUT=$(bash "$TEMP_DIR/status/server-status")
grep -Fq '**Approx. in-game time**' <<< "$STATUS_OUTPUT"
grep -Fq '442' <<< "$STATUS_OUTPUT"
grep -Eq '^☀️ 03:4[0-9]$' <<< "$STATUS_OUTPUT"

WEBHOOK_OUTPUT=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Approx. in-game time"' <<< "$WEBHOOK_OUTPUT"
grep -Fq '"value": "442"' <<< "$WEBHOOK_OUTPUT"
grep -Eq '"name":"Approx. in-game time","value": "☀️ 03:4[0-9]"' <<< "$WEBHOOK_OUTPUT"
grep -Fq '[Link](https://example.invalid/weather#442)' <<< "$WEBHOOK_OUTPUT"

: > "$TEMP_DIR/data/online-players"
PAUSED_WEBHOOK=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Current in-game day","value": "441"' <<< "$PAUSED_WEBHOOK"
grep -Fq '"name":"Approx. in-game time","value": "🌙 03:05"' <<< "$PAUSED_WEBHOOK"
grep -Fq '[Link](https://example.invalid/weather#441)' <<< "$PAUSED_WEBHOOK"

DISCONNECT_LOG_TIMESTAMP=$(date '+%m/%d/%Y %H:%M:%S')
IFS='/ :' read -r LOG_MONTH LOG_DAY LOG_YEAR LOG_HOUR LOG_MINUTE LOG_SECOND <<< "$DISCONNECT_LOG_TIMESTAMP"
DISCONNECT_EPOCH=$(date -d "$LOG_YEAR-$LOG_MONTH-$LOG_DAY $LOG_HOUR:$LOG_MINUTE:$LOG_SECOND" +%s.%N)
DISCONNECT_START_EPOCH=$(awk -v now="$DISCONNECT_EPOCH" 'BEGIN { printf "%.9f", now - 10 }')
printf '9260;5;%s\n' "$DISCONNECT_START_EPOCH" > "$TEMP_DIR/data/ingame-time"
printf '2026-10-04.00:00:00;player-one;111:1\n2026-10-04.00:00:00;player-two;123:1\n' > "$TEMP_DIR/data/online-players"
printf '%s\n' \
  "$DISCONNECT_LOG_TIMESTAMP: Destroying abandoned non persistent zdo 111:1 owner 111" \
  "$DISCONNECT_LOG_TIMESTAMP: Destroying abandoned non persistent zdo 123:1 owner 123" \
  | VSSDIR= "$TEMP_DIR/vss.log-filter"

IFS=';' read -r DISCONNECTED_TIME DISCONNECTED_DAY DISCONNECTED_EPOCH < "$TEMP_DIR/data/ingame-time"
awk -v time="$DISCONNECTED_TIME" 'BEGIN { exit !(time >= 9739 && time <= 9741) }'
[[ "$DISCONNECTED_DAY" == "6" ]]
awk -v previous="$DISCONNECT_START_EPOCH" -v updated="$DISCONNECTED_EPOCH" 'BEGIN { exit !(updated > previous) }'
[[ "$DISCONNECTED_EPOCH" == "$DISCONNECT_EPOCH" ]]
[[ ! -s "$TEMP_DIR/data/online-players" ]]

PAUSED_AFTER_DISCONNECT=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Approx. in-game time","value": "☀️ 09:52"' <<< "$PAUSED_AFTER_DISCONNECT"

RECONNECT_LOG_TIMESTAMP=$(date '+%m/%d/%Y %H:%M:%S')
IFS='/ :' read -r LOG_MONTH LOG_DAY LOG_YEAR LOG_HOUR LOG_MINUTE LOG_SECOND <<< "$RECONNECT_LOG_TIMESTAMP"
RECONNECT_EPOCH=$(date -d "$LOG_YEAR-$LOG_MONTH-$LOG_DAY $LOG_HOUR:$LOG_MINUTE:$LOG_SECOND" +%s.%N)
RECONNECT_START_EPOCH=$(awk -v now="$RECONNECT_EPOCH" 'BEGIN { printf "%.9f", now - 60 }')
printf '%s;%s;%s\n' "$DISCONNECTED_TIME" "$DISCONNECTED_DAY" "$RECONNECT_START_EPOCH" > "$TEMP_DIR/data/ingame-time"
printf '%s\n' "$RECONNECT_LOG_TIMESTAMP: Got character ZDOID from player-two : 123:2" | VSSDIR= "$TEMP_DIR/vss.log-filter"
IFS=';' read -r RECONNECTED_TIME RECONNECTED_DAY RECONNECTED_EPOCH < "$TEMP_DIR/data/ingame-time"
[[ "$RECONNECTED_TIME" == "$DISCONNECTED_TIME" ]]
[[ "$RECONNECTED_DAY" == "$DISCONNECTED_DAY" ]]
awk -v previous="$RECONNECT_START_EPOCH" -v updated="$RECONNECTED_EPOCH" 'BEGIN { exit !(updated > previous) }'
[[ "$RECONNECTED_EPOCH" == "$RECONNECT_EPOCH" ]]

if grep -q '^INGAMEDAYNUMBER=' "$TEMP_DIR/.env"; then
  printf '%s\n' 'day number should come from the stored clock sample, not .env' >&2
  exit 1
fi

mv "$TEMP_DIR/data/ingame-time" "$TEMP_DIR/data/ingame-time.saved"
NO_SAMPLE_WEBHOOK=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Current in-game day","value": "unknown"' <<< "$NO_SAMPLE_WEBHOOK"
grep -Fq '"name":"Approx. in-game time","value": "unknown"' <<< "$NO_SAMPLE_WEBHOOK"
grep -Fq '"name":"Weather forecast","value": "unknown"' <<< "$NO_SAMPLE_WEBHOOK"

printf '%s\n' 'in-game time estimate OK'