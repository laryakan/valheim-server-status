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
cp "$ROOT/lib/config.sh" "$ROOT/lib/bepinex.sh" "$CWD/lib/"
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

cat > "$CWD/bepinex_upgrade.sh" <<'EOF'
#!/bin/bash
printf 'upgrade fixture: %s\n' "${BEPINEX_RELEASES_LATEST_URL:-unset}"
exit "${MOCK_UPGRADE_EXIT:-0}"
EOF
chmod +x "$CWD/bepinex_upgrade.sh"
if ! VSS_SERVER_NAME=MissingWorld BEPINEX_RELEASES_LATEST_URL=fixture \
    "$CWD/setup" --upgrade-bepinex > "$TMPDIR_CLI/bepinex-upgrade.out" 2>&1 ||
   ! grep -Fxq 'upgrade fixture: fixture' "$TMPDIR_CLI/bepinex-upgrade.out"; then
  echo 'FAIL: direct BepInEx upgrade did not invoke the shared script without a profile' >&2
  exit 1
fi
if MOCK_UPGRADE_EXIT=7 "$CWD/setup" --upgrade-bepinex > "$TMPDIR_CLI/bepinex-upgrade-failed.out" 2>&1; then
  echo 'FAIL: direct BepInEx upgrade ignored script failure' >&2
  exit 1
else
  [ "$?" -eq 7 ] || { echo 'FAIL: direct BepInEx upgrade changed the script exit status' >&2; exit 1; }
fi
if "$CWD/setup" --upgrade-bepinex '' > "$TMPDIR_CLI/bepinex-upgrade-args.out" 2>&1; then
  echo 'FAIL: direct BepInEx upgrade accepted an argument' >&2
  exit 1
else
  [ "$?" -eq 2 ] || { echo 'FAIL: direct BepInEx upgrade returned the wrong argument error' >&2; exit 1; }
fi

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

mkdir -p "$CWD/discord"
cp "$ROOT/discord/webhook.json-sender" "$CWD/discord/"
cp "$ROOT/i18n.sh" "$CWD/i18n.sh"
cat > "$CWD/bin/curl" <<'EOF'
#!/bin/bash
method='' payload='' url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    -d) payload="$2"; shift 2 ;;
    -H|-o|--max-time) shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s|%s|%s\n' "$method" "$url" "$payload" >> "$MOCK_CURL_CALLS"
if [ -f "$MOCK_CURL_FAILURE" ]; then exit 22; fi
EOF
chmod +x "$CWD/bin/curl"
export MOCK_CURL_CALLS="$TMPDIR_CLI/curl-calls" MOCK_CURL_FAILURE="$TMPDIR_CLI/curl-failure"
write_env_value "$CWD/.env" WEBHOOKURL 'https://discord.com/api/webhooks/123/fake-token'
write_env_value "$CWD/.env" WEBHOOKID 123
write_env_value "$CWD/.env" WEBHOOKTOKEN fake-token
write_env_value "$CWD/.env" VSS_LANG fr

# The setting is off by default, then can be enabled using the modding menu.
setup_main --set-r2modman-code CliWorld aaaaaaaa-1234-abcd-9876-123456789abc >/dev/null
if [ -e "$MOCK_CURL_CALLS" ]; then
  echo 'FAIL: default R2Modman notification setting sent a message' >&2
  exit 1
fi
printf '4\n1\n0\n' | bepinex_menu > "$TMPDIR_CLI/r2-menu.out"
if ! grep -Fxq 'R2MODMANNOTIFY=1' "$CWD/.env.CliWorld"; then
  echo 'FAIL: modding menu did not enable R2Modman notifications' >&2
  exit 1
fi
printf '3\nbbbbbbbb-1234-abcd-9876-123456789abc\n0\n' | bepinex_menu > "$TMPDIR_CLI/r2-menu-code.out"
if [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 1 ] ||
   ! grep -Fq 'POST|https://discord.com/api/webhooks/123/fake-token|{"content":"CliWorld: Le code de partage R2Modman a été mis à jour: `bbbbbbbb-1234-abcd-9876-123456789abc`"}' "$MOCK_CURL_CALLS"; then
  echo 'FAIL: menu did not send exactly one localized new R2Modman notification' >&2
  exit 1
fi
setup_main --set-r2modman-code CliWorld bbbbbbbb-1234-abcd-9876-123456789abc >/dev/null
if [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 1 ]; then
  echo 'FAIL: unchanged code sent a notification' >&2
  exit 1
fi
setup_main --set-r2modman-code CliWorld '' >/dev/null
if [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 2 ] ||
   ! grep -Fq 'CliWorld: Le code de partage R2Modman a été supprimé.' "$MOCK_CURL_CALLS"; then
  echo 'FAIL: clearing the code did not send a localized removal notice' >&2
  exit 1
fi
write_env_value "$CWD/.env" VSS_LANG en
setup_main --set-r2modman-code CliWorld cccccccc-1234-abcd-9876-123456789abc >/dev/null
if [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 3 ] ||
   ! grep -Fq 'CliWorld: The R2Modman share code has been updated: `cccccccc-1234-abcd-9876-123456789abc`' "$MOCK_CURL_CALLS"; then
  echo 'FAIL: English R2Modman notification missing' >&2
  exit 1
fi
touch "$MOCK_CURL_FAILURE"
if setup_main --set-r2modman-code CliWorld dddddddd-1234-abcd-9876-123456789abc > "$TMPDIR_CLI/r2-failed.out" 2>&1 ||
   ! grep -Fq 'code saved, but Discord notification failed' "$TMPDIR_CLI/r2-failed.out" ||
   ! grep -Fq 'dddddddd-1234-abcd-9876-123456789abc' "$CWD/.env.CliWorld"; then
  echo 'FAIL: notification failure did not preserve the code and report the failure' >&2
  exit 1
fi
rm -f "$MOCK_CURL_FAILURE"
sed -i '/^R2MODMANNOTIFY=/d' "$CWD/.env.OtherWorld"
setup_main --set-r2modman-code OtherWorld eeeeeeee-1234-abcd-9876-123456789abc >/dev/null
if [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 4 ] ||
   ! grep -Fxq 'R2MODMANNOTIFY=0' "$CWD/.env.OtherWorld"; then
  echo 'FAIL: existing profile did not receive the disabled default or inherited another profile setting' >&2
  exit 1
fi
setup_main --set-r2modman-code CliWorld invalid > "$TMPDIR_CLI/r2-invalid-notify.out" 2>&1 && {
  echo 'FAIL: invalid code was accepted with notifications enabled' >&2
  exit 1
}
if [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 4 ]; then
  echo 'FAIL: invalid code sent a notification' >&2
  exit 1
fi
setup_main --set-r2modman-code CliWorld dddddddd-1234-abcd-9876-123456789abc >/dev/null
write_env_value "$CWD/.env.CliWorld" DEBUGMODE 1
if setup_main --set-r2modman-code CliWorld 11111111-1234-abcd-9876-123456789abc > "$TMPDIR_CLI/r2-debug.out" 2>&1 ||
   ! grep -Fq 'debug mode is enabled' "$TMPDIR_CLI/r2-debug.out" ||
   [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 4 ]; then
  echo 'FAIL: debug mode did not visibly prevent the notification' >&2
  exit 1
fi
write_env_value "$CWD/.env.CliWorld" DEBUGMODE 0
write_env_value "$CWD/.env" WEBHOOKTOKEN ''
if setup_main --set-r2modman-code CliWorld 22222222-1234-abcd-9876-123456789abc > "$TMPDIR_CLI/r2-missing-webhook.out" 2>&1 ||
   ! grep -Fq 'code saved, but Discord notification failed: webhook is not configured' "$TMPDIR_CLI/r2-missing-webhook.out" ||
   [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 4 ]; then
  echo 'FAIL: missing webhook did not visibly report the saved code' >&2
  exit 1
fi
write_env_value "$CWD/.env" WEBHOOKTOKEN fake-token
if ! VSS_SERVER_NAME=OtherWorld VSS_ENV_FILE="$CWD/.env.OtherWorld" VSS_CONFIG_LOADED=1 \
    "$CWD/setup" --set-r2modman-code CliWorld 33333333-1234-abcd-9876-123456789abc > "$TMPDIR_CLI/r2-executable.out" 2>&1 ||
   [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 5 ] ||
   ! grep -Fq 'CliWorld: The R2Modman share code has been updated: `33333333-1234-abcd-9876-123456789abc`' "$MOCK_CURL_CALLS"; then
  echo 'FAIL: executable notification used the wrong profile' >&2
  exit 1
fi
setup_main --set-r2modman-code CliWorld 33333333-1234-abcd-9876-123456789abc >/dev/null
printf '4\n0\n0\n' | bepinex_menu > "$TMPDIR_CLI/r2-disable.out"
setup_main --set-r2modman-code CliWorld ffffffff-1234-abcd-9876-123456789abc >/dev/null
if [ "$(wc -l < "$MOCK_CURL_CALLS")" -ne 5 ]; then
  echo 'FAIL: disabled R2Modman notification sent a message' >&2
  exit 1
fi

write_env_value "$CWD/.env.CliWorld" VSSBEPINEXENABLED 1
write_env_value "$CWD/.env.OtherWorld" VSSBEPINEXENABLED 1
write_env_value "$CWD/.env.OtherWorld" VSSBEPINEXDIR "$CWD/custom-bepinex"
shared_config="$CWD/bepinex/current/BepInEx/config/BepInEx.cfg"
cli_config="$CWD/bepinex/profiles/CliWorld/BepInEx/config/BepInEx.cfg"
other_config="$CWD/custom-bepinex/BepInEx/config/BepInEx.cfg"
mkdir -p "$(dirname "$shared_config")" "$(dirname "$cli_config")" "$(dirname "$other_config")"
printf 'shared configuration\n' > "$shared_config"
ln -s "$shared_config" "$cli_config"
ln -s "$shared_config" "$other_config"
cp "$ROOT/.env.server.dist" "$CWD/.env.DisabledWorld"
write_env_value "$CWD/.env.DisabledWorld" VHSERVERWORLD DisabledWorld
profiles_before="$(sha256sum "$CWD/.env.CliWorld" "$CWD/.env.OtherWorld" "$CWD/.env.DisabledWorld" "$CWD/.env")"
if ! VSS_SERVER_NAME=OtherWorld "$CWD/setup" --check-bepinex-config > "$TMPDIR_CLI/bepinex-check.out" 2>&1 ||
   ! grep -Fq 'CliWorld: BepInEx configuration link OK.' "$TMPDIR_CLI/bepinex-check.out" ||
   ! grep -Fq 'OtherWorld: BepInEx configuration link OK.' "$TMPDIR_CLI/bepinex-check.out" ||
   ! grep -Fq 'DisabledWorld: BepInEx disabled, no configuration to check.' "$TMPDIR_CLI/bepinex-check.out" ||
   [ "$profiles_before" != "$(sha256sum "$CWD/.env.CliWorld" "$CWD/.env.OtherWorld" "$CWD/.env.DisabledWorld" "$CWD/.env")" ]; then
  echo 'FAIL: BepInEx check did not inspect profiles without changing configuration' >&2
  exit 1
fi
rm "$other_config"
printf 'profile-specific configuration\n' > "$other_config"
if "$CWD/setup" --check-bepinex-config > "$TMPDIR_CLI/bepinex-regular.out" 2>&1 ||
   ! grep -Fq 'OtherWorld: BepInEx configuration is missing or is not a symbolic link' "$TMPDIR_CLI/bepinex-regular.out" ||
   ! grep -Fq 'CliWorld: BepInEx configuration link OK.' "$TMPDIR_CLI/bepinex-regular.out"; then
  echo 'FAIL: BepInEx check did not report a regular file and continue checking profiles' >&2
  exit 1
fi
rm "$other_config"
ln -s "$CWD/incorrect.cfg" "$other_config"
if "$CWD/setup" --check-bepinex-config > "$TMPDIR_CLI/bepinex-wrong.out" 2>&1 ||
   ! grep -Fq 'OtherWorld: BepInEx configuration link points to' "$TMPDIR_CLI/bepinex-wrong.out"; then
  echo 'FAIL: BepInEx check accepted an incorrect link' >&2
  exit 1
fi
if ! VSS_SERVER_NAME=CliWorld "$CWD/setup" --recreate-bepinex-config-link OtherWorld ||
   [ "$(readlink "$other_config")" != "$shared_config" ] ||
   [ "$(readlink "$cli_config")" != "$shared_config" ]; then
  echo 'FAIL: BepInEx link recreation did not repair the explicitly selected profile' >&2
  exit 1
fi
rm "$other_config"
printf 'profile-specific configuration\n' > "$other_config"
if ! "$CWD/setup" --recreate-bepinex-config-link OtherWorld ||
   [ ! -L "$other_config" ] || [ "$(readlink "$other_config")" != "$shared_config" ] ||
   ! grep -Fxq 'shared configuration' "$shared_config" ||
   ! "$CWD/setup" --recreate-bepinex-config-link OtherWorld; then
  echo 'FAIL: BepInEx link recreation did not replace a regular file or is not idempotent' >&2
  exit 1
fi
rm "$cli_config"
if ! "$CWD/setup" --recreate-bepinex-config-link CliWorld ||
   [ "$(readlink "$cli_config")" != "$shared_config" ] ||
   [ -n "$(find "$(dirname "$cli_config")" -maxdepth 1 -name '.vss-bepinex-link.*' -print -quit)" ]; then
  echo 'FAIL: BepInEx link recreation did not create a missing link cleanly' >&2
  exit 1
fi
rm "$other_config" "$shared_config"
ln -s "$shared_config" "$other_config"
if "$CWD/setup" --check-bepinex-config > "$TMPDIR_CLI/bepinex-broken.out" 2>&1 ||
   ! grep -Fq 'Shared BepInEx configuration is missing or inaccessible' "$TMPDIR_CLI/bepinex-broken.out"; then
  echo 'FAIL: BepInEx check accepted a broken shared link' >&2
  exit 1
fi
rm "$cli_config"
if "$CWD/setup" --check-bepinex-config > "$TMPDIR_CLI/bepinex-missing.out" 2>&1 ||
   ! grep -Fq 'CliWorld: BepInEx configuration is missing or is not a symbolic link' "$TMPDIR_CLI/bepinex-missing.out"; then
  echo 'FAIL: BepInEx check accepted a missing enabled-profile configuration' >&2
  exit 1
fi
rm "$other_config"
printf 'keep this configuration\n' > "$other_config"
if "$CWD/setup" --recreate-bepinex-config-link OtherWorld > "$TMPDIR_CLI/bepinex-recreate-missing.out" 2>&1 ||
   ! grep -Fq 'Shared BepInEx configuration is missing or inaccessible' "$TMPDIR_CLI/bepinex-recreate-missing.out" ||
   ! grep -Fxq 'keep this configuration' "$other_config" || [ -L "$other_config" ]; then
  echo 'FAIL: BepInEx link recreation changed the profile when the shared configuration was missing' >&2
  exit 1
fi
printf 'shared configuration\n' > "$shared_config"
mkdir "$cli_config"
if "$CWD/setup" --recreate-bepinex-config-link CliWorld > "$TMPDIR_CLI/bepinex-recreate-directory.out" 2>&1 ||
   ! grep -Fq 'Refusing to replace non-file BepInEx configuration' "$TMPDIR_CLI/bepinex-recreate-directory.out" ||
   [ ! -d "$cli_config" ]; then
  echo 'FAIL: BepInEx link recreation accepted a directory as the configuration' >&2
  exit 1
fi
rmdir "$cli_config"
if "$CWD/setup" --recreate-bepinex-config-link > "$TMPDIR_CLI/bepinex-recreate-args.out" 2>&1 ||
   "$CWD/setup" --recreate-bepinex-config-link CliWorld extra > "$TMPDIR_CLI/bepinex-recreate-args.out" 2>&1 ||
   "$CWD/setup" --recreate-bepinex-config-link MissingWorld > "$TMPDIR_CLI/bepinex-recreate-profile.out" 2>&1; then
  echo 'FAIL: BepInEx link recreation accepted invalid arguments or a missing profile' >&2
  exit 1
fi
if "$CWD/setup" --check-bepinex-config CliWorld > "$TMPDIR_CLI/bepinex-args.out" 2>&1; then
  echo 'FAIL: BepInEx check accepted an unexpected argument' >&2
  exit 1
else
  [ "$?" -eq 2 ] || { echo 'FAIL: BepInEx check returned the wrong argument error' >&2; exit 1; }
fi
EMPTY_DIR="$TMPDIR_CLI/empty"
mkdir -p "$EMPTY_DIR/lib"
cp "$ROOT/setup" "$EMPTY_DIR/setup"
cp "$ROOT/lib/config.sh" "$ROOT/lib/validation.sh" "$EMPTY_DIR/lib/"
if "$EMPTY_DIR/setup" --check-bepinex-config > "$TMPDIR_CLI/bepinex-empty.out" 2>&1 ||
   ! grep -Fq 'No server profiles found' "$TMPDIR_CLI/bepinex-empty.out"; then
  echo 'FAIL: BepInEx check accepted an installation without profiles' >&2
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
