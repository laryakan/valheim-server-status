#!/bin/bash
set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/data" "$TEMP_DIR/logs" "$TEMP_DIR/status" "$TEMP_DIR/launcher"
cp "$ROOT_DIR/vss.log-filter" "$TEMP_DIR/vss.log-filter"
cp "$ROOT_DIR/status/server-status" "$TEMP_DIR/status/server-status"
cp "$ROOT_DIR/i18n.sh" "$TEMP_DIR/i18n.sh"
printf '\n' > "$TEMP_DIR/launcher/launcher-args"

cat > "$TEMP_DIR/.env" <<EOF
set -o allexport
DEBUGMODE=0
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

printf '%s\n' \
  'Time 795831,77718268, day:441 nextm:795870,000010729 skipspeed:3,18523567076772' \
  | VSSDIR= "$TEMP_DIR/vss.log-filter"

IFS=';' read -r SAMPLE_TIME SAMPLE_DAY NEXTM_TIME SKIPSPEED SAMPLE_EPOCH < "$TEMP_DIR/data/ingame-time"
[[ "$SAMPLE_TIME" == "795831.77718268" ]]
[[ "$SAMPLE_DAY" == "441" ]]
[[ "$NEXTM_TIME" == "795870.000010729" ]]
[[ "$SKIPSPEED" == "3.18523567076772" ]]
[[ "$SAMPLE_EPOCH" =~ ^[0-9]+\.[0-9]{9}$ ]]

SAMPLE_EPOCH=$(awk -v now="$(date +%s.%N)" 'BEGIN { printf "%.9f", now - 13 }')
printf '%s;%s;%s;%s;%s\n' "$SAMPLE_TIME" "$SAMPLE_DAY" "$NEXTM_TIME" "$SKIPSPEED" "$SAMPLE_EPOCH" > "$TEMP_DIR/data/ingame-time"
touch "$TEMP_DIR/data/online-players" "$TEMP_DIR/data/offline-players" "$TEMP_DIR/data/last-world-save"

STATUS_OUTPUT=$(bash "$TEMP_DIR/status/server-status")
grep -Fq '**Approx. in-game time**' <<< "$STATUS_OUTPUT"
grep -Fq '442' <<< "$STATUS_OUTPUT"
grep -Eq '^03:3[6-9]$' <<< "$STATUS_OUTPUT"

WEBHOOK_OUTPUT=$(bash "$TEMP_DIR/status/server-status" --for-webhook)
grep -Fq '"name":"Approx. in-game time"' <<< "$WEBHOOK_OUTPUT"
grep -Fq '"value": "442"' <<< "$WEBHOOK_OUTPUT"
grep -Fq '[Link](https://example.invalid/weather#442)' <<< "$WEBHOOK_OUTPUT"
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