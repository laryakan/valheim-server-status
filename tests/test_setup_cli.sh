#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_CLI="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CLI"' EXIT

source "$ROOT/setup" >/dev/null

CWD="$TMPDIR_CLI"
mkdir -p "$CWD/bin" "$CWD/lib" "$CWD/launcher" "$CWD/examples" "$CWD/data"
printf '#!/bin/sh\nexit 0\n' > "$CWD/bin/dig"
chmod +x "$CWD/bin/dig"
PATH="$CWD/bin:$PATH"
cp "$ROOT/lib/config.sh" "$CWD/lib/config.sh"
cp "$ROOT/.env.dist" "$CWD/.env.dist"
cp "$ROOT/examples/launcher-args" "$CWD/examples/launcher-args"
cp "$ROOT/.env.dist" "$CWD/.env.CliWorld"
write_env_value "$CWD/.env.CliWorld" VHSERVERWORLD 'CliWorld'

called_action=''
start_valheim_service() { called_action='start'; }
stop_valheim_service() { called_action='stop'; }
restart_valheim_service() { called_action='restart'; }
status_valheim_service() { called_action='status'; }
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

echo "direct setup commands OK"
