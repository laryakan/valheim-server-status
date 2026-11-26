#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/lib" "$TEST_DIR/data" "$TEST_DIR/discord" "$TEST_DIR/bin"
cp "$ROOT/vss.maintenance" "$TEST_DIR/"
cp "$ROOT/lib/config.sh" "$TEST_DIR/lib/"
cp "$ROOT/i18n.sh" "$TEST_DIR/"
cat > "$TEST_DIR/setup" <<'EOF'
#!/bin/bash
case "${1:-}" in
  --list)
    printf 'Alpha\nBeta\n'
    ;;
  --maintenance-update)
    printf 'maintenance update%s\n' "${2:+ $2}" >> "$MAINTENANCE_EVENTS"
    ;;
  *)
    exit 2
    ;;
esac
EOF
cat > "$TEST_DIR/discord/webhook.json-sender" <<'EOF'
#!/bin/bash
printf 'webhook %s\n' "$VSS_SERVER_NAME" >> "$MAINTENANCE_EVENTS"
cat >> "$MAINTENANCE_EVENTS"
EOF
cat > "$TEST_DIR/bin/sleep" <<'EOF'
#!/bin/sh
printf 'sleep %s\n' "$*" >> "$MAINTENANCE_EVENTS"
exit 0
EOF
chmod +x "$TEST_DIR/setup" "$TEST_DIR/discord/webhook.json-sender" "$TEST_DIR/bin/sleep"
cat > "$TEST_DIR/.env.Alpha" <<'EOF'
VHSERVERWORLD=Alpha
EOF
cat > "$TEST_DIR/.env.Beta" <<'EOF'
VHSERVERWORLD=Beta
EOF
cat > "$TEST_DIR/.env" <<'EOF'
VSS_COMMON_CONFIG_VERSION=3
VSS_LANG=fr
EOF
printf '%s\n' player > "$TEST_DIR/data/online-players.Alpha"
: > "$TEST_DIR/data/online-players.Beta"
export MAINTENANCE_EVENTS="$TEST_DIR/events"
export PATH="$TEST_DIR/bin:$PATH"

if ! "$TEST_DIR/vss.maintenance" > "$TEST_DIR/output" 2>&1; then
  cat "$TEST_DIR/output"
  echo "FAIL: planned maintenance script failed" >&2
  exit 1
fi
if [ "$(grep -c '^maintenance update$' "$MAINTENANCE_EVENTS")" -ne 1 ] ||
   ! grep -Fxq 'webhook Alpha' "$MAINTENANCE_EVENTS" ||
   ! grep -Fq '"title": "Maintenance planifiée"' "$MAINTENANCE_EVENTS" ||
   ! grep -Fq 'Préparez-vous à vous déconnecter !' "$MAINTENANCE_EVENTS"; then
  cat "$TEST_DIR/output" "$MAINTENANCE_EVENTS" >&2
  echo "FAIL: planned maintenance did not aggregate profiles and invoke one global update" >&2
  exit 1
fi

: > "$MAINTENANCE_EVENTS"
if ! "$TEST_DIR/vss.maintenance" --no-upgrade > "$TEST_DIR/output" 2>&1 ||
   ! grep -Fxq 'maintenance update --no-upgrade' "$MAINTENANCE_EVENTS" ||
   ! grep -Fxq 'webhook Alpha' "$MAINTENANCE_EVENTS" ||
   ! grep -Fxq 'sleep 5m' "$MAINTENANCE_EVENTS"; then
  echo 'FAIL: restart-only planned maintenance did not retain the player warning or pass the option' >&2
  exit 1
fi
: > "$MAINTENANCE_EVENTS"
if "$TEST_DIR/vss.maintenance" --unknown > "$TEST_DIR/output" 2>&1 ||
   "$TEST_DIR/vss.maintenance" --no-upgrade extra > "$TEST_DIR/output" 2>&1 ||
   [ -s "$MAINTENANCE_EVENTS" ]; then
  echo 'FAIL: invalid planned maintenance options triggered side effects' >&2
  exit 1
fi

echo "planned maintenance aggregates profiles OK"
