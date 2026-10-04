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
LIBDIR="$TEMP_DIR/lib"
DEBUGMODE=0
EVENTREALTIME=0
VALHEIMSERVERLOGDIR="$TEMP_DIR/logs"
CONNECTEDPLAYERSFILE="$TEMP_DIR/data/online-players"
OFFLINEPLAYERSFILE="$TEMP_DIR/data/offline-players"
STEAMIDMAPFILE="$TEMP_DIR/data/steamid-player-map"
LASTWORLDSAVEFILE="$TEMP_DIR/data/last-world-save"
INGAMETIMEFILE="$TEMP_DIR/data/ingame-time"
INGAMETIMEEVENTSFILE="$TEMP_DIR/data/ingame-time-events"
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
	VSSDIR="$TEMP_DIR" bash -c 'source "$1"; declare -F T >/dev/null; [[ "$VSSDIR" == "$2" ]]' _ "$module" "$TEMP_DIR"
done

REAL_SAMPLE='10/04/2026 02:26:54: Time 797262,099461015, day:442 nextm:797670,000010729 skipspeed:33,9917124761268'
printf '%s\n' "$REAL_SAMPLE" | VSSDIR= "$TEMP_DIR/vss.log-filter"
[[ "$(cat "$TEMP_DIR/data/ingame-time")" == "$REAL_SAMPLE" ]]
[[ "$(cat "$TEMP_DIR/data/ingame-time-events")" == "paused|$REAL_SAMPLE" ]]

VSSDIR="$TEMP_DIR"
source "$TEMP_DIR/lib/server-status-ingame-time.sh"
VALHEIM_PID="$PPID"
CONNECTEDPLAYERSFILE="$TEMP_DIR/data/online-players"
server_status_calculate_ingame_clock
[[ "$CURRENT_INGAMEDAYNUMBER" == "442" ]]
[[ "$INGAME_TIME_LABEL" == "☀️ 03:36" ]]
[[ "$(server_status_project_ingame_time 797670.000010729 442 49316)" == 469\|* ]]
[[ "$(server_status_project_ingame_time 270 1 0)" == *'|☀️ 03:36' ]]
[[ "$(server_status_project_ingame_time 1530 1 0)" == *'|☀️ 20:24' ]]
[[ "$(server_status_project_ingame_time 1531.25 1 0)" == *'|🌙 20:25' ]]
[[ "$(server_status_project_ingame_time 269.979166667 1 0)" == *'|🌙 03:35' ]]
[[ "$(server_status_project_ingame_time 795870.000010729 441 1800)" == 442\|* ]]

touch "$TEMP_DIR/data/offline-players" "$TEMP_DIR/data/last-world-save"
printf '2026-10-04.00:00:00;test-player;111:1\n' > "$TEMP_DIR/data/online-players"
SAMPLE_TIMESTAMP=$(date '+%m/%d/%Y %H:%M:%S')
ACTIVE_SAMPLE="$SAMPLE_TIMESTAMP: Time 795831,77718268, day:441 nextm:795870,000010729 skipspeed:3,18523567076772"
printf '%s\n' "$ACTIVE_SAMPLE" | VSSDIR= "$TEMP_DIR/vss.log-filter"
[[ "$(cat "$TEMP_DIR/data/ingame-time-events")" == "active|$ACTIVE_SAMPLE" ]]

WEBHOOK_OUTPUT=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Current in-game day","value": "441"' <<< "$WEBHOOK_OUTPUT"
grep -Fq '[Link](https://example.invalid/weather#441)' <<< "$WEBHOOK_OUTPUT"

PAUSE_TIMESTAMP=$(date '+%m/%d/%Y %H:%M:%S')
printf '%s\n' "$PAUSE_TIMESTAMP: Destroying abandoned non persistent zdo 111:1 owner 111" | VSSDIR= "$TEMP_DIR/vss.log-filter"
[[ ! -s "$TEMP_DIR/data/online-players" ]]
PAUSED_WEBHOOK=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Current in-game day","value": "441"' <<< "$PAUSED_WEBHOOK"
grep -Eq '"name":"Approx. in-game time","value": "☀️ 03:3[6-9]"' <<< "$PAUSED_WEBHOOK"

RECONNECT_TIMESTAMP=$(date '+%m/%d/%Y %H:%M:%S')
printf '%s\n' "$RECONNECT_TIMESTAMP: Got character ZDOID from test-player : 111:2" | VSSDIR= "$TEMP_DIR/vss.log-filter"
[[ "$(tail -n 1 "$TEMP_DIR/data/ingame-time-events")" == "active|$RECONNECT_TIMESTAMP: Got character ZDOID from test-player : 111:2" ]]
RECONNECTED_WEBHOOK=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Current in-game day","value": "441"' <<< "$RECONNECTED_WEBHOOK"

NEXT_DAY_SAMPLE='10/04/2026 02:26:54: Time 797262,099461015, day:442 nextm:797670,000010729 skipspeed:33,9917124761268'
printf '%s\n' "$NEXT_DAY_SAMPLE" | VSSDIR= "$TEMP_DIR/vss.log-filter"
[[ "$(cat "$TEMP_DIR/data/ingame-time")" == "$NEXT_DAY_SAMPLE" ]]
[[ "$(cat "$TEMP_DIR/data/ingame-time-events")" == "active|$NEXT_DAY_SAMPLE" ]]

mv "$TEMP_DIR/data/ingame-time" "$TEMP_DIR/data/ingame-time.saved"
NO_SAMPLE_WEBHOOK=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Current in-game day","value": "unknown"' <<< "$NO_SAMPLE_WEBHOOK"
grep -Fq '"name":"Approx. in-game time","value": "unknown"' <<< "$NO_SAMPLE_WEBHOOK"
grep -Fq '"name":"Weather forecast","value": "unknown"' <<< "$NO_SAMPLE_WEBHOOK"

printf '%s\n' 'in-game time estimate OK'