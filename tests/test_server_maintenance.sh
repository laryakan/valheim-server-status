#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_BIN="$TEST_DIR/bin"
mkdir -p "$MOCK_BIN" "$TEST_DIR/server" "$TEST_DIR/discord" "$TEST_DIR/lib"
cp "$ROOT/lib/config.sh" "$TEST_DIR/lib/config.sh"
export MOCK_BIN TEST_DIR
export INSTALLED_UNITS="$TEST_DIR/installed-units"
export ACTIVE_UNITS="$TEST_DIR/active-units"
export MAINTENANCE_EVENTS="$TEST_DIR/events"
export REAL_TIMEOUT="$(command -v timeout)"

cat > "$MOCK_BIN/sudo" <<'EOF'
#!/bin/bash
case "${1:-}" in
  systemctl)
    shift
    exec "$MOCK_BIN/systemctl" "$@"
    ;;
  -u)
    shift 2
    exec "$@"
    ;;
  *)
    exit 2
    ;;
esac
EOF
cat > "$MOCK_BIN/systemctl" <<'EOF'
#!/bin/bash
action="$1"
unit="${2:-}"
case "$action" in
  cat)
    grep -Fxq "$unit" "$INSTALLED_UNITS"
    ;;
  is-active)
    unit="${3:-}"
    grep -Fxq "$unit" "$ACTIVE_UNITS"
    ;;
  stop)
    printf 'stop %s\n' "$unit" >> "$MAINTENANCE_EVENTS"
    grep -Fvx "$unit" "$ACTIVE_UNITS" > "$ACTIVE_UNITS.tmp" || true
    mv "$ACTIVE_UNITS.tmp" "$ACTIVE_UNITS"
    ;;
  start)
    printf 'start %s\n' "$unit" >> "$MAINTENANCE_EVENTS"
    printf '%s\n' "$unit" >> "$ACTIVE_UNITS"
    ;;
  *)
    exit 2
    ;;
esac
EOF
cat > "$MOCK_BIN/steamcmd" <<'EOF'
#!/bin/bash
printf 'steamcmd %s\n' "$*" >> "$MAINTENANCE_EVENTS"
[ "${FAIL_UPDATE:-0}" -eq 0 ]
EOF
cat > "$MOCK_BIN/timeout" <<'EOF'
#!/bin/bash
if [ "${FAIL_DISCORD_TIMEOUT:-0}" -eq 1 ]; then
  exit 124
fi
exec "$REAL_TIMEOUT" "$@"
EOF
cat > "$TEST_DIR/discord/update" <<'EOF'
#!/bin/bash
if [ -n "${VSS_ENV_FILE:-}" ] || [ -n "${VSS_CONFIG_LOADED:-}" ]; then
  echo 'Inherited a previously loaded profile' >&2
  exit 1
fi
unit="valheim-server.$VSS_SERVER_NAME.service"
if grep -Fxq "$unit" "$ACTIVE_UNITS"; then
  echo 'Discord update ran before the service stopped' >&2
  exit 1
fi
source "$TEST_DIR/lib/config.sh"
vss_load_config "$TEST_DIR" || exit 1
printf 'discord %s %s\n' "$VSS_SERVER_NAME" "$STATUSMESSAGEID" >> "$MAINTENANCE_EVENTS"
[ "${FAIL_DISCORD:-0}" -eq 0 ]
EOF
chmod +x "$MOCK_BIN/"*
chmod +x "$TEST_DIR/discord/update"
export PATH="$MOCK_BIN:$PATH"

source "$ROOT/setup" >/dev/null
CWD="$TEST_DIR"
cat > "$CWD/.env" <<'EOF'
VSS_COMMON_CONFIG_VERSION=3
WEBHOOKURL='https://discord.com/api/webhooks/123456/fake-token'
WEBHOOKID=123456
WEBHOOKTOKEN=fake-token
EOF
cat > "$CWD/.env.Alpha" <<'EOF'
VHSERVERWORLD=Alpha
STATUSMESSAGEID=111
EOF
cat > "$CWD/.env.Beta" <<'EOF'
VHSERVERWORLD=Beta
STATUSMESSAGEID=222
EOF
printf '%s\n' valheim-server.Alpha.service valheim-server.Beta.service > "$INSTALLED_UNITS"
printf '%s\n' valheim-server.Alpha.service > "$ACTIVE_UNITS"
: > "$MAINTENANCE_EVENTS"
VHSERVERDIR="$TEST_DIR/server"
STEAMCMDPATH="$MOCK_BIN/steamcmd"
USERSERVICE='valheim'
unset VSSSTEAMBRANCH

if ! run_server_maintenance > "$TEST_DIR/success.out" 2>&1; then
  cat "$TEST_DIR/success.out"
  echo "FAIL: maintenance update failed" >&2
  exit 1
fi
if [ "$(cat "$ACTIVE_UNITS")" != 'valheim-server.Alpha.service' ]; then
  echo "FAIL: maintenance did not restore only the previously active service" >&2
  exit 1
fi
if [ "$(grep -c '^stop ' "$MAINTENANCE_EVENTS")" -ne 2 ] ||
   [ "$(grep -c '^start ' "$MAINTENANCE_EVENTS")" -ne 1 ] ||
   ! grep -Fxq 'start valheim-server.Alpha.service' "$MAINTENANCE_EVENTS" ||
   grep -Fxq 'start valheim-server.Beta.service' "$MAINTENANCE_EVENTS"; then
  echo "FAIL: maintenance did not stop all instances and restore only the active one" >&2
  exit 1
fi
stop_line="$(grep -n '^stop ' "$MAINTENANCE_EVENTS" | tail -n 1 | cut -d: -f1)"
steam_line="$(grep -n '^steamcmd ' "$MAINTENANCE_EVENTS" | cut -d: -f1)"
start_line="$(grep -n '^start ' "$MAINTENANCE_EVENTS" | cut -d: -f1)"
if [ "$stop_line" -ge "$steam_line" ] || [ "$steam_line" -ge "$start_line" ]; then
  echo "FAIL: maintenance update was not ordered after stops and before restarts" >&2
  exit 1
fi
for profile in Alpha Beta; do
  case "$profile" in Alpha) id=111 ;; Beta) id=222 ;; esac
  discord_line="$(grep -n "^discord $profile $id$" "$MAINTENANCE_EVENTS" | cut -d: -f1)"
  if [ -z "$discord_line" ] || [ "$discord_line" -le "$stop_line" ] || [ "$discord_line" -ge "$steam_line" ]; then
    echo "FAIL: Discord was not updated once for $profile after stopping and before SteamCMD" >&2
    exit 1
  fi
done
if [ "$(grep -c '^discord ' "$MAINTENANCE_EVENTS")" -ne 2 ]; then
  echo 'FAIL: maintenance duplicated Discord updates' >&2
  exit 1
fi
if ! grep -Fxq "steamcmd +force_install_dir $VHSERVERDIR +login anonymous +app_update 896660 -beta default_old validate +exit" "$MAINTENANCE_EVENTS"; then
  echo "FAIL: maintenance did not use the default branch" >&2
  exit 1
fi

VSS_SERVER_NAME=Alpha
load_server_profile() { [ "$1" = Alpha ]; }
VSSSTEAMBRANCH=default_pre1_0
: > "$MAINTENANCE_EVENTS"
if ! setup_main --maintenance-update > "$TEST_DIR/configured-branch.out" 2>&1 ||
   ! grep -Fxq "steamcmd +force_install_dir $VHSERVERDIR +login anonymous +app_update 896660 -beta default_pre1_0 validate +exit" "$MAINTENANCE_EVENTS"; then
  echo "FAIL: direct maintenance did not use the configured shared branch" >&2
  exit 1
fi

: > "$MAINTENANCE_EVENTS"
if ! setup_main --maintenance-update public-test > "$TEST_DIR/branch.out" 2>&1 ||
   ! grep -Fxq "steamcmd +force_install_dir $VHSERVERDIR +login anonymous +app_update 896660 -beta public-test validate +exit" "$MAINTENANCE_EVENTS" ||
   [ "$(cat "$ACTIVE_UNITS")" != 'valheim-server.Alpha.service' ]; then
  echo "FAIL: direct maintenance did not pass the branch or restore the active service" >&2
  exit 1
fi

: > "$MAINTENANCE_EVENTS"
if setup_main --maintenance-update typo > "$TEST_DIR/invalid.out" 2>&1 ||
   ! grep -Fq 'Invalid Valheim Steam branch' "$TEST_DIR/invalid.out" ||
   [ -s "$MAINTENANCE_EVENTS" ]; then
  echo "FAIL: invalid Steam branch was accepted or maintenance started" >&2
  exit 1
fi
VSSSTEAMBRANCH=unknown
if setup_main --maintenance-update > "$TEST_DIR/invalid-config.out" 2>&1 ||
   ! grep -Fq 'Invalid Valheim Steam branch: unknown' "$TEST_DIR/invalid-config.out" ||
   [ -s "$MAINTENANCE_EVENTS" ]; then
  echo "FAIL: invalid configured branch was accepted or maintenance started" >&2
  exit 1
fi
if ! setup_main --maintenance-update public > "$TEST_DIR/override.out" 2>&1 ||
   ! grep -Fxq "steamcmd +force_install_dir $VHSERVERDIR +login anonymous +app_update 896660 -beta public validate +exit" "$MAINTENANCE_EVENTS"; then
  echo "FAIL: explicit branch did not override the invalid shared setting" >&2
  exit 1
fi
: > "$MAINTENANCE_EVENTS"
VSSSTEAMBRANCH=''
if run_server_maintenance > "$TEST_DIR/invalid-config.out" 2>&1 ||
   ! grep -Fq 'Invalid Valheim Steam branch: <empty>' "$TEST_DIR/invalid-config.out" ||
   [ -s "$MAINTENANCE_EVENTS" ]; then
  echo "FAIL: empty configured branch was accepted or maintenance started" >&2
  exit 1
fi
if setup_main --maintenance-update '' > "$TEST_DIR/invalid.out" 2>&1 ||
   setup_main --maintenance-update public extra > "$TEST_DIR/invalid.out" 2>&1 ||
   [ -s "$MAINTENANCE_EVENTS" ]; then
  echo "FAIL: invalid maintenance arguments were accepted or maintenance started" >&2
  exit 1
fi

printf '%s\n' valheim-server.Beta.service > "$ACTIVE_UNITS"
: > "$MAINTENANCE_EVENTS"
if FAIL_UPDATE=1 run_server_maintenance public > "$TEST_DIR/failure.out" 2>&1; then
  echo "FAIL: maintenance reported success after SteamCMD failed" >&2
  exit 1
fi
if [ "$(cat "$ACTIVE_UNITS")" != 'valheim-server.Beta.service' ] ||
   ! grep -Fxq 'start valheim-server.Beta.service' "$MAINTENANCE_EVENTS" ||
   ! grep -Fxq "steamcmd +force_install_dir $VHSERVERDIR +login anonymous +app_update 896660 -beta public validate +exit" "$MAINTENANCE_EVENTS"; then
  echo "FAIL: previously active instances were not restored after an update failure" >&2
  exit 1
fi

sed -i 's/^STATUSMESSAGEID=.*/STATUSMESSAGEID=/' "$TEST_DIR/.env.Beta"
export STATUSMESSAGEID=111 VSS_ENV_FILE="$TEST_DIR/.env.Alpha" VSS_CONFIG_LOADED=1
: > "$MAINTENANCE_EVENTS"
if ! FAIL_DISCORD=1 run_server_maintenance public > "$TEST_DIR/discord-failure.out" 2>&1 ||
   ! grep -Fxq 'discord Alpha 111' "$MAINTENANCE_EVENTS" ||
   grep -q '^discord Beta ' "$MAINTENANCE_EVENTS" ||
   ! grep -Fq 'Discord maintenance update failed or timed out for profile Alpha' "$TEST_DIR/discord-failure.out" ||
   ! grep -Fq 'No valid Discord status message ID for profile Beta' "$TEST_DIR/discord-failure.out" ||
   ! grep -Fxq 'start valheim-server.Beta.service' "$MAINTENANCE_EVENTS"; then
  echo 'FAIL: Discord failure or missing message ID affected maintenance restoration' >&2
  exit 1
fi
: > "$MAINTENANCE_EVENTS"
if ! FAIL_DISCORD_TIMEOUT=1 run_server_maintenance public > "$TEST_DIR/discord-timeout.out" 2>&1 ||
   ! grep -Fq 'Discord maintenance update failed or timed out for profile Alpha' "$TEST_DIR/discord-timeout.out" ||
   ! grep -Fxq 'start valheim-server.Beta.service' "$MAINTENANCE_EVENTS"; then
  echo 'FAIL: Discord timeout prevented maintenance or service restoration' >&2
  exit 1
fi

echo "multi-server maintenance update OK"
