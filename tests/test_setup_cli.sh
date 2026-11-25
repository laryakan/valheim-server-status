#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_CLI="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CLI"' EXIT

source "$ROOT/setup" >/dev/null
if declare -F migrate_legacy_config >/dev/null; then
  echo "FAIL: V2 migration code is still loaded into setup" >&2
  exit 1
fi

CWD="$TMPDIR_CLI"
mkdir -p "$CWD/bin" "$CWD/lib" "$CWD/launcher" "$CWD/examples" "$CWD/data"
printf '#!/bin/sh\nexit 0\n' > "$CWD/bin/dig"
chmod +x "$CWD/bin/dig"
PATH="$CWD/bin:$PATH"
cp "$ROOT/lib/config.sh" "$CWD/lib/config.sh"
cp "$ROOT/lib/validation.sh" "$CWD/lib/validation.sh"
cp "$ROOT/setup" "$CWD/setup"
cp "$ROOT/.env.server.dist" "$CWD/.env.server.dist"
cp "$ROOT/.env.common.dist" "$CWD/.env.common.dist"
cp "$ROOT/examples/launcher-args" "$CWD/examples/launcher-args"
cp "$ROOT/.env.server.dist" "$CWD/.env.CliWorld"
write_env_value "$CWD/.env.CliWorld" VHSERVERWORLD 'CliWorld'

called_action=''
start_valheim_service() { called_action='start'; }
stop_valheim_service() { called_action='stop'; }
restart_valheim_service() { called_action='restart'; }
status_valheim_service() { called_action='status'; }
check_ufw_profile_rules() { called_action='firewall'; }
run_discord_update() { called_action='discord'; }
new_menu() { called_action='menu'; return 91; }

if ! setup_main --restart-server CliWorld; then
  echo "FAIL: direct server restart command failed" >&2
  exit 1
fi
if [ "$called_action" != 'restart' ]; then
  echo "FAIL: restart command did not dispatch to the server action" >&2
  exit 1
fi

if ! setup_main --discord-update CliWorld; then
  echo "FAIL: direct Discord update command failed" >&2
  exit 1
fi
if [ "$called_action" != 'discord' ]; then
  echo "FAIL: Discord command did not dispatch to the update action" >&2
  exit 1
fi

for action in start stop status; do
  if ! setup_main "--$action-server" CliWorld; then
    printf 'FAIL: direct %s command failed\n' "$action" >&2
    exit 1
  fi
  if [ "$called_action" != "$action" ]; then
    printf 'FAIL: direct %s command dispatched incorrectly\n' "$action" >&2
    exit 1
  fi
done

if ! setup_main --check-firewall CliWorld; then
  echo "FAIL: direct firewall check command failed" >&2
  exit 1
fi
if [ "$called_action" != 'firewall' ]; then
  echo "FAIL: firewall check command did not dispatch to the profile action" >&2
  exit 1
fi

if replace_env_value R2MODMANCODE not-a-uuid; then
  echo "FAIL: setup accepted an invalid R2Modman code" >&2
  exit 1
fi
if ! replace_env_value R2MODMANCODE 01a1eaf3-9be3-9083-b9b4-26768368368e ||
   ! grep -Fq 'R2MODMANCODE="01a1eaf3-9be3-9083-b9b4-26768368368e"' "$CWD/.env.CliWorld"; then
  echo "FAIL: setup did not save a valid R2Modman code" >&2
  exit 1
fi

cp "$ROOT/.env.server.dist" "$CWD/.env.OtherWorld"
write_env_value "$CWD/.env.OtherWorld" VHSERVERWORLD 'OtherWorld'
write_env_value "$CWD/.env.OtherWorld" VHSERVERPORT 2460
other_before="$(sha256sum "$CWD/.env.OtherWorld")"
called_action='not called'
if ! setup_main --set-r2modman-code CliWorld 12345678-1234-abcd-9876-123456789abc ||
   ! grep -Fxq 'R2MODMANCODE="12345678-1234-abcd-9876-123456789abc"' "$CWD/.env.CliWorld" ||
   [ "$other_before" != "$(sha256sum "$CWD/.env.OtherWorld")" ] ||
   [ "$called_action" != 'not called' ]; then
  echo "FAIL: direct R2Modman update changed the wrong profile or invoked another action" >&2
  exit 1
fi

profile_before="$(sha256sum "$CWD/.env.CliWorld")"
for invalid_code in not-a-uuid 'invalid|code'; do
  if setup_main --set-r2modman-code CliWorld "$invalid_code" > "$TMPDIR_CLI/r2-invalid.out" 2>&1 ||
     ! grep -Fq 'R2MODMANCODE must be a UUID' "$TMPDIR_CLI/r2-invalid.out" ||
     [ "$profile_before" != "$(sha256sum "$CWD/.env.CliWorld")" ]; then
    echo "FAIL: invalid direct R2Modman code was accepted or changed the profile" >&2
    exit 1
  fi
done
if setup_main --set-r2modman-code CliWorld > "$TMPDIR_CLI/r2-args.out" 2>&1 ||
   setup_main --set-r2modman-code CliWorld code extra > "$TMPDIR_CLI/r2-args.out" 2>&1 ||
   setup_main --set-r2modman-code MissingWorld 12345678-1234-abcd-9876-123456789abc > "$TMPDIR_CLI/r2-missing.out" 2>&1; then
  echo "FAIL: direct R2Modman command accepted invalid arguments or a missing profile" >&2
  exit 1
fi
if ! setup_main --set-r2modman-code CliWorld '' ||
   ! grep -Fxq 'R2MODMANCODE=' "$CWD/.env.CliWorld" ||
   [ "$other_before" != "$(sha256sum "$CWD/.env.OtherWorld")" ]; then
  echo "FAIL: direct R2Modman command did not clear the selected profile's code" >&2
  exit 1
fi
if ! VSS_SERVER_NAME=OtherWorld "$CWD/setup" --set-r2modman-code CliWorld 12345678-1234-abcd-9876-123456789abc ||
   ! grep -Fxq 'R2MODMANCODE="12345678-1234-abcd-9876-123456789abc"' "$CWD/.env.CliWorld" ||
   [ "$other_before" != "$(sha256sum "$CWD/.env.OtherWorld")" ]; then
  echo "FAIL: executable R2Modman command did not use the explicitly named profile" >&2
  exit 1
fi

CONFLICT_DIR="$TMPDIR_CLI/conflict"
mkdir -p "$CONFLICT_DIR/data" "$CONFLICT_DIR/examples"
cp "$ROOT/examples/launcher-args" "$CONFLICT_DIR/examples/launcher-args"
cat > "$CONFLICT_DIR/.env" <<EOF
VSSDIR="$CONFLICT_DIR"
VHSERVERWORLD='ConflictWorld'
CONNECTEDPLAYERSFILE="$CONFLICT_DIR/data/online-players"
OFFLINEPLAYERSFILE="$CONFLICT_DIR/data/offline-players"
STEAMIDMAPFILE="$CONFLICT_DIR/data/steamid-player-map"
LASTWORLDSAVEFILE="$CONFLICT_DIR/data/last-world-save"
EOF
printf '%s\n' 'existing profile state' > "$CONFLICT_DIR/data/online-players.ConflictWorld"
CWD="$CONFLICT_DIR"
called_action='not called'
if setup_main --restart-server ConflictWorld > "$TMPDIR_CLI/migration-conflict.out" 2>&1; then
  echo "FAIL: direct action ignored a migration state-file conflict" >&2
  exit 1
fi
if ! grep -Fq 'Run ./migrate-v2-to-v3' \
  "$TMPDIR_CLI/migration-conflict.out"; then
  echo "FAIL: setup did not direct legacy installations to the migration command" >&2
  exit 1
fi
if [ "$called_action" != 'not called' ] ||
   [ -e "$CWD/.env.ConflictWorld" ] ||
   [ ! -e "$CWD/.env" ] ||
   ! grep -Fxq 'existing profile state' "$CWD/data/online-players.ConflictWorld"; then
  echo "FAIL: setup changed profile or state data while reporting a legacy installation" >&2
  exit 1
fi

if setup_main --restart-server > "$TMPDIR_CLI/missing-profile.out"; then
  echo "FAIL: restart command accepted a missing profile name" >&2
  exit 1
else
  result=$?
  if [ "$result" -ne 2 ]; then
    echo "FAIL: missing profile name returned the wrong exit status" >&2
    exit 1
  fi
fi
if ! grep -Fq 'requires exactly one server name' "$TMPDIR_CLI/missing-profile.out"; then
  echo "FAIL: missing profile error was not shown" >&2
  exit 1
fi

if [ -f "$ROOT/crash.log" ]; then
  crash_log_before="$(sha256sum "$ROOT/crash.log" | awk '{print $1}')"
else
  crash_log_before='missing'
fi
if "$ROOT/setup" --restart-server > "$TMPDIR_CLI/direct-error.out" 2>&1; then
  echo "FAIL: direct setup command accepted a missing profile" >&2
  exit 1
else
  result=$?
  if [ "$result" -ne 2 ]; then
    echo "FAIL: direct setup command returned the wrong argument error status" >&2
    exit 1
  fi
fi
if [ "$crash_log_before" = 'missing' ]; then
  [ ! -e "$ROOT/crash.log" ] || {
    echo "FAIL: setup created crash.log" >&2
    exit 1
  }
elif [ "$crash_log_before" != "$(sha256sum "$ROOT/crash.log" | awk '{print $1}')" ]; then
  echo "FAIL: setup wrote to crash.log" >&2
  exit 1
fi

echo "direct setup commands OK"
