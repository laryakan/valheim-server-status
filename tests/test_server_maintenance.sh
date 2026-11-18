#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_BIN="$TEST_DIR/bin"
mkdir -p "$MOCK_BIN" "$TEST_DIR/server"
export MOCK_BIN TEST_DIR
export INSTALLED_UNITS="$TEST_DIR/installed-units"
export ACTIVE_UNITS="$TEST_DIR/active-units"
export MAINTENANCE_EVENTS="$TEST_DIR/events"

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
chmod +x "$MOCK_BIN/"*
export PATH="$MOCK_BIN:$PATH"

source "$ROOT/setup" >/dev/null
CWD="$TEST_DIR"
touch "$CWD/.env.Alpha" "$CWD/.env.Beta"
printf '%s\n' valheim-server.Alpha.service valheim-server.Beta.service > "$INSTALLED_UNITS"
printf '%s\n' valheim-server.Alpha.service > "$ACTIVE_UNITS"
: > "$MAINTENANCE_EVENTS"
VHSERVERDIR="$TEST_DIR/server"
STEAMCMDPATH="$MOCK_BIN/steamcmd"
USERSERVICE='valheim'

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

printf '%s\n' valheim-server.Beta.service > "$ACTIVE_UNITS"
: > "$MAINTENANCE_EVENTS"
if FAIL_UPDATE=1 run_server_maintenance > "$TEST_DIR/failure.out" 2>&1; then
  echo "FAIL: maintenance reported success after SteamCMD failed" >&2
  exit 1
fi
if [ "$(cat "$ACTIVE_UNITS")" != 'valheim-server.Beta.service' ] ||
   ! grep -Fxq 'start valheim-server.Beta.service' "$MAINTENANCE_EVENTS"; then
  echo "FAIL: previously active instances were not restored after an update failure" >&2
  exit 1
fi

echo "multi-server maintenance update OK"
