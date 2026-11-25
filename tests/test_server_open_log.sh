#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/lib" "$TEST_DIR/bin"
cp "$ROOT/lib/config.sh" "$TEST_DIR/lib/config.sh"
cp "$ROOT/vss.log-filter" "$TEST_DIR/vss.log-filter"
REAL_DATE="$(command -v date)"
export REAL_DATE
cat > "$TEST_DIR/bin/date" <<'EOF'
#!/bin/bash
if [ "${1:-}" = '+%F %T|%d/%m/%Y %H:%M:%S' ]; then
  if [ "${MOCK_DATE_FAIL:-0}" = 1 ]; then
    printf 'Mock clock failure\n' >&2
    exit 1
  fi
  exec "$REAL_DATE" -d "$MOCK_NOW" "$1"
else
  exec "$REAL_DATE" "$@"
fi
EOF
chmod +x "$TEST_DIR/bin/date"
export PATH="$TEST_DIR/bin:$PATH"
export MOCK_NOW='2026-11-25 17:30:01'
printf 'VSS_COMMON_CONFIG_VERSION=3\n' > "$TEST_DIR/.env"
cat > "$TEST_DIR/.env.Steam" <<'EOF'
VHSERVERWORLD=Steam
VALSERVERLASTOPEN=''
VSSBEPINEXENABLED=0
EOF
cat > "$TEST_DIR/.env.Crossplay" <<'EOF'
VHSERVERWORLD=Crossplay
VSSBEPINEXENABLED=1
EOF
cat > "$TEST_DIR/.env.NoVersion" <<'EOF'
VHSERVERWORLD=NoVersion
VSSBEPINEXENABLED=1
EOF
cat > "$TEST_DIR/.env.Akanheim" <<'EOF'
VHSERVERWORLD=Akanheim
VSSBEPINEXENABLED=1
VALSERVERLASTOPEN=''
VALSERVERVERSION='0.0.0'
VALSERVERLASTUPDATE='0'
BEPINEXVERSION='0.0.0'
BEPINEXLASTUPDATE='0'
EOF

printf '%s\n' \
  '11/25/2026 14:56:25: Opened Steam server' \
  '11/25/2026 15:00:00: Opened Steam server failed' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Steam "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:01"' "$TEST_DIR/.env.Steam"; then
  echo 'FAIL: Steam server opening was not recorded or a non-opening line was accepted' >&2
  exit 1
fi
printf '%s\n' 'Valheim version: l-1.0.7 (network version 39)' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Steam "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERVERSION="l-1.0.7"' "$TEST_DIR/.env.Steam" ||
   ! grep -Fxq 'VALSERVERLASTUPDATE="25/11/2026 17:30:01"' "$TEST_DIR/.env.Steam"; then
  echo 'FAIL: missing Valheim version fields were not recorded in the profile' >&2
  exit 1
fi
printf '%s\n' '[Message:   BepInEx] BepInEx 5.4.23.5 - valheim_server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Steam "$TEST_DIR/vss.log-filter"
if grep -q '^BEPINEXVERSION=' "$TEST_DIR/.env.Steam"; then
  echo 'FAIL: BepInEx version was recorded for a disabled profile' >&2
  exit 1
fi
printf '%s\n' '[Message:   BepInEx] BepInEx 5.4.23.5 - valheim_server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=NoVersion "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'BEPINEXVERSION="5.4.23.5"' "$TEST_DIR/.env.NoVersion" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:01"' "$TEST_DIR/.env.NoVersion"; then
  echo 'FAIL: missing BepInEx version fields were not recorded in the profile' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:02'
printf '%s\n' \
  '[Info   : Unity Log] 11/25/2026 15:01:02: Opened PlayFab server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:02"' "$TEST_DIR/.env.Crossplay" ||
   ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:01"' "$TEST_DIR/.env.Steam"; then
  echo 'FAIL: PlayFab opening was not recorded independently in the existing profile' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:03'
printf '%s\n' '[Info   : Unity Log] 11/25/2026 17:07:00: Opened Steam server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:03"' "$TEST_DIR/.env.Akanheim"; then
  echo 'FAIL: BepInEx-prefixed Steam opening was not recorded in its profile' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:04'
printf '%s\n' '11/25/2026  17:08:00: Opened   Steam  server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:04"' "$TEST_DIR/.env.Akanheim"; then
  echo 'FAIL: vanilla Steam opening with extra whitespace was not recorded' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:05'
printf '%s\n' '[Info   : Unity Log] 11/25/2026 17:09:00: [Server] Opened Steam server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:05"' "$TEST_DIR/.env.Akanheim"; then
  echo 'FAIL: Steam opening with an additional log prefix was not recorded' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:06'
printf '%s\n' '[Info   : Unity Log] Opened Steam server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:06"' "$TEST_DIR/.env.Akanheim"; then
  echo 'FAIL: opening without a log timestamp did not use the server clock' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:07'
printf '%s\n' \
  '[Info   : Unity Log] Valheim version: l-1.0.14 (network version 40)' \
  '[Message:   BepInEx] BepInEx 5.4.23.5 - valheim_server (07/09/2020 23:14:40)' \
  '[Info   : Unity Log] World save (5/5) done. Total time [319ms]' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERVERSION="l-1.0.14"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'VALSERVERLASTUPDATE="25/11/2026 17:30:07"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'BEPINEXVERSION="5.4.23.5"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:07"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq '25/11/2026 17:30:07' "$TEST_DIR/data/last-world-save.Akanheim"; then
  echo 'FAIL: version or save capture did not use the server clock' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:08'
printf '%s\n' \
  '09/10/2020 01:27:33: Valheim version: l-1.0.15 (network version 40)' \
  '[Message:   BepInEx] BepInEx 5.4.23.6 - valheim_server' \
  '09/10/2020 01:27:33: World save (4/5) done. Total time [319ms]' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERVERSION="l-1.0.15"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'VALSERVERLASTUPDATE="25/11/2026 17:30:08"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'BEPINEXVERSION="5.4.23.6"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:08"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq '25/11/2026 17:30:07' "$TEST_DIR/data/last-world-save.Akanheim"; then
  echo 'FAIL: timestamped version, BepInEx without timestamp, or incomplete save handling' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:09'
printf '%s\n' \
  'Valheim version: l-1.0.15 (network version 40)' \
  '[Message:   BepInEx] BepInEx 5.4.23.6 - valheim_server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTUPDATE="25/11/2026 17:30:08"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:08"' "$TEST_DIR/.env.Akanheim"; then
  echo 'FAIL: unchanged version changed its update time' >&2
  exit 1
fi
printf 'BEPINEXVERSION="5.4.23.6"\nBEPINEXLASTUPDATE="0"\n' >> "$TEST_DIR/.env.Crossplay"
printf '%s\n' '[Message:   BepInEx] BepInEx 5.4.23.6 - valheim_server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'BEPINEXLASTUPDATE="0"' "$TEST_DIR/.env.Crossplay" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:08"' "$TEST_DIR/.env.Akanheim"; then
  echo 'FAIL: unchanged BepInEx version changed its unknown date or another profile' >&2
  exit 1
fi
printf 'VALSERVERVERSION="l-1.0.15"\nVALSERVERLASTUPDATE="0"\n' >> "$TEST_DIR/.env.Crossplay"
printf '%s\n' 'Valheim version: l-1.0.15 (network version 40)' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTUPDATE="0"' "$TEST_DIR/.env.Crossplay"; then
  echo 'FAIL: unchanged Valheim version changed its unknown date' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:10'
printf '%s\n' '[Message:   BepInEx] BepInEx 5.4.23.7 - valheim_server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'BEPINEXVERSION="5.4.23.7"' "$TEST_DIR/.env.Crossplay" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:10"' "$TEST_DIR/.env.Crossplay" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:08"' "$TEST_DIR/.env.Akanheim"; then
  echo 'FAIL: changed BepInEx version did not update only its own profile' >&2
  exit 1
fi
MOCK_NOW='2026-11-25 17:30:08'
printf '%s\n' \
  'Opened Steam server' \
  'Valheim version: l-1.0.16' \
  '[Message:   BepInEx] BepInEx 5.4.23.7 - valheim_server (07/10/2020 23:14:40)' \
  'World save (5/5) done. Total time [319ms]' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED MOCK_DATE_FAIL=1 VSS_SERVER_NAME=Akanheim "$TEST_DIR/vss.log-filter" \
    2>"$TEST_DIR/clock.err"
if ! grep -Fq 'Could not timestamp server opening' "$TEST_DIR/clock.err" ||
   ! grep -Fq 'Could not timestamp Valheim version' "$TEST_DIR/clock.err" ||
   ! grep -Fq 'Could not timestamp BepInEx version' "$TEST_DIR/clock.err" ||
   ! grep -Fq 'Could not timestamp world save' "$TEST_DIR/clock.err" ||
   ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:06"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'VALSERVERVERSION="l-1.0.15"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'BEPINEXVERSION="5.4.23.6"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq 'BEPINEXLASTUPDATE="25/11/2026 17:30:08"' "$TEST_DIR/.env.Akanheim" ||
   ! grep -Fxq '25/11/2026 17:30:07' "$TEST_DIR/data/last-world-save.Akanheim"; then
  echo 'FAIL: clock failure was not reported or changed recorded state' >&2
  exit 1
fi
LOG_FILE="$TEST_DIR/valheim-logs.d/$(date +%Y-%m-%d).Akanheim.stdout.log"
if ! grep -Fxq '25/11/2026 17:30:07: [Info   : Unity Log] Valheim version: l-1.0.14 (network version 40)' "$LOG_FILE" ||
   ! grep -Fxq '25/11/2026 17:30:07: [Message:   BepInEx] BepInEx 5.4.23.5 - valheim_server (07/09/2020 23:14:40)' "$LOG_FILE" ||
   ! grep -Fxq 'Opened Steam server' "$LOG_FILE"; then
  echo 'FAIL: captured lines were not timestamped or preserved on clock failure' >&2
  exit 1
fi
source "$TEST_DIR/lib/config.sh"
MOCK_SERVICE_STATE=inactive
MOCK_SERVICE_STARTED=''
systemctl() {
  if [ "${MOCK_SERVICE_MISSING:-0}" = 1 ]; then
    return 4
  fi
  if [ "${MOCK_SERVICE_ERROR:-0}" = 1 ]; then
    printf 'Mock systemd error\n' >&2
    return 1
  fi
  if [ "$1" != show ] || [ "$2" != "valheim-server.$VSS_SERVER_NAME.service" ]; then
    printf 'Unexpected systemctl request: %s\n' "$*" >&2
    return 1
  fi
  printf 'LoadState=%s\nActiveState=%s\nActiveEnterTimestamp=%s\n' \
    "${MOCK_SERVICE_LOAD:-loaded}" "$MOCK_SERVICE_STATE" "$MOCK_SERVICE_STARTED"
}
VSS_SERVER_NAME=Crossplay
VSS_ENV_FILE="$TEST_DIR/.env.Crossplay"
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: inactive service was not offline' >&2
  exit 1
fi

LOG_FILE="$TEST_DIR/valheim-logs.d/$(date +%Y-%m-%d).Crossplay.stdout.log"
LOG_LINES_BEFORE="$(wc -l < "$LOG_FILE")"
printf '%s\n' '11/25/2026 16:00:00: Opened Steam server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter" --tail-pipe-input
if ! grep -Fxq 'VALSERVERLASTOPEN="2026-11-25 17:30:08"' "$TEST_DIR/.env.Crossplay" ||
   [ "$(grep -c '^VALSERVERLASTOPEN=' "$TEST_DIR/.env.Crossplay")" -ne 1 ] ||
   [ "$(wc -l < "$LOG_FILE")" -ne "$LOG_LINES_BEFORE" ]; then
  echo 'FAIL: a later opening did not replace the previous value' >&2
  exit 1
fi

printf '%s\n' '11/25/2026 16:21:00: Opened PlayFab server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: inactive service with a newer opening did not report offline' >&2
  exit 1
fi
MOCK_SERVICE_STATE=active
MOCK_SERVICE_STARTED='11/25/2026 16:00:00'
if [ "$(vss_server_state)" != 'online' ]; then
  echo 'FAIL: active service with a detected opening did not report online' >&2
  exit 1
fi
sed -i 's/^VALSERVERLASTOPEN=.*/VALSERVERLASTOPEN="invalid"/' "$TEST_DIR/.env.Crossplay"
if [ "$(vss_server_state 2>"$TEST_DIR/invalid.err")" != 'starting' ] ||
   ! grep -Fq 'Invalid server opening timestamp' "$TEST_DIR/invalid.err"; then
  echo 'FAIL: invalid opening timestamp was not reported while the service was starting' >&2
  exit 1
fi

VSS_SERVER_NAME=Akanheim
VSS_ENV_FILE="$TEST_DIR/.env.Akanheim"
MOCK_SERVICE_STARTED='Wed 2026-11-25 17:05:00 CET'
if [ "$(TZ=Europe/Paris vss_server_state)" != 'online' ]; then
  echo 'FAIL: BepInEx Steam opening did not make the active server online' >&2
  exit 1
fi

VSS_SERVER_NAME=Starting
VSS_ENV_FILE="$TEST_DIR/.env.Starting"
printf 'VHSERVERWORLD=Starting\n' > "$VSS_ENV_FILE"
MOCK_SERVICE_STATE=active
MOCK_SERVICE_STARTED='2000-01-01 00:00:00'
if [ "$(vss_server_state)" != 'starting' ]; then
  echo 'FAIL: active service without events did not remain starting indefinitely' >&2
  exit 1
fi

printf 'VALSERVERLASTOPEN="01/01/2000 00:00:00"\n' >> "$VSS_ENV_FILE"
if [ "$(vss_server_state)" != 'online' ]; then
  echo 'FAIL: opening at service start did not report online' >&2
  exit 1
fi
MOCK_SERVICE_STARTED='2000-01-02 00:00:00'
if [ "$(vss_server_state)" != 'starting' ]; then
  echo 'FAIL: events from an earlier service run prevented starting' >&2
  exit 1
fi
sed -i 's/^VALSERVERLASTOPEN=.*/VALSERVERLASTOPEN="11\/12\/2026 00:00:00"/' "$VSS_ENV_FILE"
MOCK_SERVICE_STARTED='2026-11-13 00:00:00'
if [ "$(vss_server_state)" != 'starting' ]; then
  echo 'FAIL: legacy US-format opening was not interpreted as November 12' >&2
  exit 1
fi
MOCK_SERVICE_STATE=inactive
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: inactive service incorrectly reported starting' >&2
  exit 1
fi
MOCK_SERVICE_STATE=activating
if [ "$(vss_server_state)" != 'starting' ]; then
  echo 'FAIL: activating service did not report starting' >&2
  exit 1
fi
MOCK_SERVICE_STATE=active
MOCK_SERVICE_STARTED=''
if [ "$(vss_server_state 2>"$TEST_DIR/service.err")" != 'offline' ] ||
   ! grep -Fq 'Could not determine start time' "$TEST_DIR/service.err"; then
  echo 'FAIL: missing service start time did not report offline and a diagnostic' >&2
  exit 1
fi
MOCK_SERVICE_ERROR=1
if [ "$(vss_server_state 2>"$TEST_DIR/service.err")" != 'offline' ] ||
   ! grep -Fq 'Could not inspect service' "$TEST_DIR/service.err"; then
  echo 'FAIL: systemd inspection failure was not reported as offline' >&2
  exit 1
fi
MOCK_SERVICE_ERROR=0
MOCK_SERVICE_LOAD=not-found
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: service with not-found load state did not report offline' >&2
  exit 1
fi
MOCK_SERVICE_MISSING=1
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: missing service did not report offline' >&2
  exit 1
fi

echo 'Steam and PlayFab opening and service status detection OK'
