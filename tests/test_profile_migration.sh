#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_PROFILE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PROFILE"' EXIT

mkdir -p "$TMPDIR_PROFILE/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMPDIR_PROFILE/bin/dig"
chmod +x "$TMPDIR_PROFILE/bin/dig"
PATH="$TMPDIR_PROFILE/bin:$PATH"

source "$ROOT/setup" >/dev/null
source "$ROOT/migrate-v2-to-v3"
CWD="$TMPDIR_PROFILE"
mkdir -p "$CWD/data" "$CWD/launcher" "$CWD/examples" "$CWD/systemd"
cp "$ROOT/.env.dist" "$CWD/.env.dist"
cp "$ROOT/examples/launcher-args" "$CWD/examples/launcher-args"
printf '%s\n' '-saveinterval 1800' > "$CWD/launcher/launcher-args"

cat > "$CWD/.env" <<EOF
VSSDIR="$CWD"
VHSERVERWORLD='LegacyWorld'
CONNECTEDPLAYERSFILE="$CWD/data/online-players"
OFFLINEPLAYERSFILE="$CWD/data/offline-players"
STEAMIDMAPFILE="$CWD/data/steamid-player-map"
LASTWORLDSAVEFILE="$CWD/data/last-world-save"
EOF
source "$CWD/.env"
printf '%s\n' 'online data' > "$CWD/data/online-players"
printf '%s\n' 'offline data' > "$CWD/data/offline-players"
printf '%s\n' 'steam map' > "$CWD/data/steamid-player-map"
printf '%s\n' 'save timestamp' > "$CWD/data/last-world-save"

if ! migrate_legacy_config; then
  echo "FAIL: legacy configuration migration failed" >&2
  exit 1
fi

if [ -e "$CWD/.env" ] || [ ! -f "$CWD/.env.LegacyWorld" ]; then
  echo "FAIL: legacy .env was not renamed to its profile name" >&2
  exit 1
fi
if [ ! -f "$CWD/launcher/launcher-args.LegacyWorld" ] ||
   [ -e "$CWD/launcher/launcher-args" ]; then
  echo "FAIL: launcher arguments were not migrated" >&2
  exit 1
fi
if ! grep -Fxq 'online data' "$CWD/data/online-players.LegacyWorld" ||
   ! grep -Fxq 'offline data' "$CWD/data/offline-players.LegacyWorld" ||
   ! grep -Fxq 'steam map' "$CWD/data/steamid-player-map.LegacyWorld" ||
   ! grep -Fxq 'save timestamp' "$CWD/data/last-world-save.LegacyWorld"; then
  echo "FAIL: VSS state data was not preserved during migration" >&2
  exit 1
fi
if ! grep -Fq "valheim-server.LegacyWorld.service" "$CWD/.env.LegacyWorld"; then
  echo "FAIL: migrated profile service names were not updated" >&2
  exit 1
fi

write_env_value "$CWD/.env.LegacyWorld" VHSERVERPORT 2456
write_env_value "$CWD/.env.LegacyWorld" STATUSPORT 8181
if ! create_server_profile NewWorld; then
  echo "FAIL: new server profile could not be created" >&2
  exit 1
fi
if ! grep -Fxq 'VHSERVERPORT=2466' "$CWD/.env.NewWorld" ||
   ! grep -Fxq 'STATUSPORT=8182' "$CWD/.env.NewWorld"; then
  echo "FAIL: new profile did not receive distinct default ports" >&2
  exit 1
fi

CREATE_DIR="$TMPDIR_PROFILE/create"
mkdir -p "$CREATE_DIR/data" "$CREATE_DIR/launcher" "$CREATE_DIR/examples"
cp "$ROOT/.env.dist" "$CREATE_DIR/.env.dist"
cp "$ROOT/examples/launcher-args" "$CREATE_DIR/examples/launcher-args"
cat > "$CREATE_DIR/.env" <<EOF
VSSDIR="$CREATE_DIR"
VHSERVERWORLD='CreateWorld'
EOF
CWD="$CREATE_DIR"
new_menu() { :; }
clear() { :; }
if setup_main --create CreateWorld > "$TMPDIR_PROFILE/setup-legacy.out" 2>&1; then
  echo "FAIL: setup automatically migrated a legacy profile" >&2
  exit 1
fi
if ! grep -Fq 'Run ./migrate-v2-to-v3' "$TMPDIR_PROFILE/setup-legacy.out" ||
   [ ! -f "$CWD/.env" ] || [ -e "$CWD/.env.CreateWorld" ]; then
  echo "FAIL: setup did not leave V2 migration to the standalone command" >&2
  exit 1
fi

echo "legacy profile migration OK"
