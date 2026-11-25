#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/lib"
cp "$ROOT/lib/config.sh" "$TEST_DIR/lib/config.sh"
cp "$ROOT/vss.log-filter" "$TEST_DIR/vss.log-filter"
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

printf '%s\n' \
  '11/25/2026 14:56:25: Opened Steam server' \
  '11/25/2026 15:00:00: Opened Steam server failed' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Steam "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="11/25/2026 14:56:25"' "$TEST_DIR/.env.Steam"; then
  echo 'FAIL: Steam server opening was not recorded or a non-opening line was accepted' >&2
  exit 1
fi

printf '%s\n' \
  '[Info   : Unity Log] 11/25/2026 15:01:02: Opened PlayFab server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTOPEN="11/25/2026 15:01:02"' "$TEST_DIR/.env.Crossplay" ||
   ! grep -Fxq 'VALSERVERLASTOPEN="11/25/2026 14:56:25"' "$TEST_DIR/.env.Steam"; then
  echo 'FAIL: PlayFab opening was not recorded independently in the existing profile' >&2
  exit 1
fi
source "$TEST_DIR/lib/config.sh"
MOCK_SERVICE_STATE=inactive
MOCK_SERVICE_STARTED=''
systemctl() {
  if [ "$1" != show ] || [ "$2" != "valheim-server.$VSS_SERVER_NAME.service" ]; then
    printf 'Unexpected systemctl request: %s\n' "$*" >&2
    return 1
  fi
  printf 'LoadState=loaded\nActiveState=%s\nActiveEnterTimestamp=%s\n' \
    "$MOCK_SERVICE_STATE" "$MOCK_SERVICE_STARTED"
}
VSS_SERVER_NAME=Crossplay
VSS_ENV_FILE="$TEST_DIR/.env.Crossplay"
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: status was online without a shutdown timestamp' >&2
  exit 1
fi

printf '%s\n' '11/25/2026 16:00:00: Opened Steam server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter" --tail-pipe-input
if ! grep -Fxq 'VALSERVERLASTOPEN="11/25/2026 16:00:00"' "$TEST_DIR/.env.Crossplay" ||
   [ "$(grep -c '^VALSERVERLASTOPEN=' "$TEST_DIR/.env.Crossplay")" -ne 1 ]; then
  echo 'FAIL: a later opening did not replace the previous value' >&2
  exit 1
fi

printf '%s\n' \
  '[Info   : Unity Log] 11/25/2026 16:15:00: Input "System module state changed to: Shutdown"' \
  '[Info   : Unity Log] 11/25/2026 16:16:00: Input "System module state changed to: Shutdown failed"' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTSHUTDOWN="11/25/2026 16:15:00"' "$TEST_DIR/.env.Crossplay" ||
   grep -q '^VALSERVERLASTSHUTDOWN=' "$TEST_DIR/.env.Steam" ||
   ! grep -Fxq 'VALSERVERLASTOPEN="11/25/2026 16:00:00"' "$TEST_DIR/.env.Crossplay"; then
  echo 'FAIL: shutdown was not recorded independently or a non-shutdown line was accepted' >&2
  exit 1
fi

printf '%s\n' '11/25/2026 16:20:00: System module state changed to: Shutdown' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if ! grep -Fxq 'VALSERVERLASTSHUTDOWN="11/25/2026 16:20:00"' "$TEST_DIR/.env.Crossplay" ||
   [ "$(grep -c '^VALSERVERLASTSHUTDOWN=' "$TEST_DIR/.env.Crossplay")" -ne 1 ]; then
  echo 'FAIL: a later shutdown did not replace the previous value' >&2
  exit 1
fi
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: shutdown after opening did not report offline' >&2
  exit 1
fi
printf '%s\n' '11/25/2026 16:21:00: Opened PlayFab server' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if [ "$(vss_server_state)" != 'online' ]; then
  echo 'FAIL: opening after shutdown did not report online' >&2
  exit 1
fi
printf '%s\n' '11/25/2026 16:21:00: System module state changed to: Shutdown' |
  env -u VSS_ENV_FILE -u VSS_CONFIG_LOADED VSS_SERVER_NAME=Crossplay "$TEST_DIR/vss.log-filter"
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: equal opening and shutdown timestamps did not report offline' >&2
  exit 1
fi
sed -i 's/^VALSERVERLASTOPEN=.*/VALSERVERLASTOPEN="invalid"/' "$TEST_DIR/.env.Crossplay"
if [ "$(vss_server_state 2>"$TEST_DIR/invalid.err")" != 'offline' ] ||
   ! grep -Fq 'Invalid server opening timestamp' "$TEST_DIR/invalid.err"; then
  echo 'FAIL: invalid opening timestamp was not reported as offline' >&2
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
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: opening without a shutdown timestamp did not report offline' >&2
  exit 1
fi
printf 'VALSERVERLASTSHUTDOWN="12/31/1999 23:59:00"\n' >> "$VSS_ENV_FILE"
if [ "$(vss_server_state)" != 'online' ]; then
  echo 'FAIL: opening at service start did not report online' >&2
  exit 1
fi
printf 'VALSERVERLASTSHUTDOWN="01/01/2000 00:02:00"\n' >> "$VSS_ENV_FILE"
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: shutdown after service start did not report offline' >&2
  exit 1
fi
MOCK_SERVICE_STARTED='2000-01-02 00:00:00'
if [ "$(vss_server_state)" != 'starting' ]; then
  echo 'FAIL: events from an earlier service run prevented starting' >&2
  exit 1
fi
MOCK_SERVICE_STATE=inactive
if [ "$(vss_server_state)" != 'offline' ]; then
  echo 'FAIL: inactive service incorrectly reported starting' >&2
  exit 1
fi
MOCK_SERVICE_STATE=active
MOCK_SERVICE_STARTED=''
if [ "$(vss_server_state 2>"$TEST_DIR/service.err")" != 'offline' ] ||
   ! grep -Fq 'Could not determine start time' "$TEST_DIR/service.err"; then
  echo 'FAIL: missing service start time did not report an error and use log timestamps' >&2
  exit 1
fi

echo 'Steam and PlayFab opening and shutdown detection OK'
