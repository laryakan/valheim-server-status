#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_UI="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_UI"' EXIT

source "$ROOT/setup" >/dev/null

VSS_SERVER_NAME='UiWorld'
VHSERVERWORLD='UiWorld'
VHSERVERPORT=2456
STATUSPORT=8181
vss_find_server_pid() { return 1; }
setup_ui_unit_state() { printf 'not installed'; }

menu_output="$(printf 'invalid\n0\n' | NO_COLOR=1 new_menu)"
for expected in \
  'VALHEIM SERVER STATUS' \
  'Profile: UiWorld' \
  'World: UiWorld  |  Valheim: offline' \
  'Ports: game 2456  |  HTTP 8181' \
  'Discord and webhook' \
  'Switch server profile' \
  'Select an action:' \
  'Unknown option: invalid' \
  'Exit'; do
  if [[ "$menu_output" != *"$expected"* ]]; then
    printf 'FAIL: setup menu is missing "%s"\n' "$expected" >&2
    exit 1
  fi
done
if [[ "$menu_output" == *$'\033'* ]]; then
  echo "FAIL: setup menu emitted color codes when output was not a terminal" >&2
  exit 1
fi
if [[ "$menu_output" == *'PROFILES OVERVIEW'* ]]; then
  echo "FAIL: setup dashboard showed the profile overview outside profile selection" >&2
  exit 1
fi

PROFILE_OVERVIEW_DIR="$TMPDIR_UI/profile-overview"
mkdir -p "$PROFILE_OVERVIEW_DIR/data"
mkdir -p "$PROFILE_OVERVIEW_DIR/lib"
cp "$ROOT/lib/config.sh" "$PROFILE_OVERVIEW_DIR/lib/config.sh"
printf 'VSS_COMMON_CONFIG_VERSION=3\n' > "$PROFILE_OVERVIEW_DIR/.env"
cat > "$PROFILE_OVERVIEW_DIR/.env.OverviewA" <<'EOF'
VHSERVERWORLD=OverviewA
VHSERVERNAME='Server A'
VHSERVERPORT=2456
VHSERVERSEED=SeedA
VSSBEPINEXENABLED=1
EOF
cat > "$PROFILE_OVERVIEW_DIR/.env.OverviewB" <<'EOF'
VHSERVERWORLD=OverviewB
VHSERVERNAME='Server B'
VHSERVERPORT=2460
VHSERVERSEED=SeedB
VSSBEPINEXENABLED=0
VALSERVERPID=''
EOF
printf 'VALSERVERPID=%s\n' "$$" >> "$PROFILE_OVERVIEW_DIR/.env.OverviewA"
printf 'steamid;PlayerA;zdoid\n' > "$PROFILE_OVERVIEW_DIR/data/online-players.OverviewA"
touch "$PROFILE_OVERVIEW_DIR/data/online-players.OverviewB"
CWD="$PROFILE_OVERVIEW_DIR"
VSS_SERVER_NAME='OverviewA'
vss_find_server_pid() { printf '1\n'; }
overview_output="$(setup_ui_profiles_overview)"
for expected in \
  'OverviewA (current)' \
  'Server: Server A' \
  'State: online | Port: 2456' \
  'BepInEx: on' \
  'Seed: SeedA' \
  'Players: 1 connected' \
  'OverviewB' \
  'State: offline | Port: 2460' \
  'BepInEx: off' \
  'Seed: SeedB' \
  'Players: 0 connected'; do
  if [[ "$overview_output" != *"$expected"* ]]; then
    printf 'FAIL: profile overview is missing "%s"\n' "$expected" >&2
    exit 1
  fi
done
vss_find_server_pid() { return 1; }

cat > "$TMPDIR_UI/keyboard-choice.sh" <<EOF
source "$ROOT/setup" >/dev/null
selected=1
while :; do
  setup_ui_menu_option "\$selected" 1 one
  setup_ui_menu_option "\$selected" 2 two
  setup_ui_menu_option "\$selected" 3 three
  setup_ui_menu_option "\$selected" 0 Exit
  setup_ui_read_menu_choice 3 "\$selected"
  if [[ "\$SETUP_UI_CHOICE" == '__redraw__' ]]; then
    selected="\$SETUP_UI_SELECTED_CHOICE"
    continue
  fi
  break
done
printf 'KEYBOARD_CHOICE=%s\\n' "\$SETUP_UI_CHOICE"
EOF
keyboard_output="$(printf '\033[B\n' | script -qec "bash '$TMPDIR_UI/keyboard-choice.sh'" /dev/null)"
if [[ "$keyboard_output" != *'KEYBOARD_CHOICE=2'* ||
      "$keyboard_output" != *$'\033[7m   2  two\033[0m'* ]]; then
  echo "FAIL: down-arrow navigation did not select the next menu option" >&2
  exit 1
fi
cat > "$TMPDIR_UI/keyboard-main-menu.sh" <<EOF
source "$ROOT/setup" >/dev/null
VSS_SERVER_NAME=UiWorld
VHSERVERWORLD=UiWorld
VHSERVERPORT=2456
STATUSPORT=8181
vss_find_server_pid() { return 1; }
setup_ui_unit_state() { printf 'not installed'; }
new_menu
EOF
keyboard_main_output="$(printf '\033[B\n0\n0\n' | TERM=xterm script -qec "bash '$TMPDIR_UI/keyboard-main-menu.sh'" /dev/null)"
if [[ "$keyboard_main_output" != *$'\033[7m   2  Valheim launcher and server\033[0m'* ||
      "$keyboard_main_output" == *'> 1. Discord and webhook <'* ]]; then
  echo "FAIL: main menu did not highlight the selected item in its option list" >&2
  exit 1
fi

VSS_SERVER_NAME='UiWorld'
launcher_output="$(printf '5\n0\n' | NO_COLOR=1 launcher_menu)"
if [[ "$launcher_output" != *'Valheim server'* ||
      "$launcher_output" != *'Show world/profile ID (read-only)'* ||
      "$launcher_output" != *'rename is not supported here'* ]]; then
  echo "FAIL: launcher menu does not present the world/profile ID as read-only" >&2
  exit 1
fi
admin_output="$(printf '0\n' | NO_COLOR=1 admin_menu)"
if [[ "$admin_output" != *'Admin and access lists'* ||
      "$admin_output" != *'shared by all profiles'* ]]; then
  echo "FAIL: admin menu does not use the shared dashboard style" >&2
  exit 1
fi
http_output="$(printf '0\n' | NO_COLOR=1 http_status_menu)"
if [[ "$http_output" != *'HTTP status endpoint'* ||
      "$http_output" != *'Select an action:'* ]]; then
  echo "FAIL: HTTP status menu does not use the shared dashboard style" >&2
  exit 1
fi
discord_output="$(printf '0\n' | NO_COLOR=1 discord_menu)"
if [[ "$discord_output" != *'One Discord webhook URL is shared by all profiles'* ||
      "$discord_output" != *'only message IDs differ'* ]]; then
  echo "FAIL: Discord menu does not explain shared webhook behavior" >&2
  exit 1
fi

NO_COLOR=1
color_output="$(ColorRed warning)"
if [[ "$color_output" != 'warning' ]]; then
  echo "FAIL: setup color helper ignored NO_COLOR" >&2
  exit 1
fi

VHSERVERSERVICENAME='valheim-server.UiWorld.service'
VSSPIPESERVICENAME='vss.pipe.UiWorld.service'
VSSHTTPSERVICENAME='vss.http.UiWorld.service'
removal_calls=''
remove_profile_cron() { removal_calls="${removal_calls}cron:$1;"; }
uninstall_service() { removal_calls="${removal_calls}$1;"; }

if ! remove_profile_services <<< 'no' > "$TMPDIR_UI/remove-cancel.out"; then
  echo "FAIL: declining profile service removal returned an error" >&2
  exit 1
fi
if [ -n "$removal_calls" ]; then
  echo "FAIL: declining profile service removal performed actions" >&2
  exit 1
fi
if ! grep -Fq 'were kept' "$TMPDIR_UI/remove-cancel.out"; then
  echo "FAIL: declining profile service removal did not report that resources were kept" >&2
  exit 1
fi

if ! remove_profile_services <<< 'REMOVE' > "$TMPDIR_UI/remove-confirm.out"; then
  echo "FAIL: confirming profile service removal returned an error" >&2
  exit 1
fi
expected_removal_calls="$VHSERVERSERVICENAME;$VSSHTTPSERVICENAME;$VSSPIPESERVICENAME;cron:UiWorld;"
if [ "$removal_calls" != "$expected_removal_calls" ]; then
  echo "FAIL: confirming profile service removal did not remove the expected profile resources" >&2
  exit 1
fi

mkdir -p "$TMPDIR_UI/bepinex"
cat > "$TMPDIR_UI/bepinex/install_bepinex.sh" <<'EOF'
#!/bin/bash
printf 'install\n' >> "$BEPINEX_TEST_CALLS"
[[ "${BEPINEX_FAIL_INSTALL:-0}" != 1 ]]
EOF
cat > "$TMPDIR_UI/bepinex/remove_bepinex.sh" <<'EOF'
#!/bin/bash
printf 'remove\n' >> "$BEPINEX_TEST_CALLS"
EOF
chmod +x "$TMPDIR_UI/bepinex/install_bepinex.sh" "$TMPDIR_UI/bepinex/remove_bepinex.sh"
export BEPINEX_TEST_CALLS="$TMPDIR_UI/bepinex.calls"
VSSDIR="$TMPDIR_UI"
VSS_SERVER_NAME='UiWorld'
VSSPIPESERVICENAME='vss.pipe.UiWorld.service'
setup_calls=''
replace_env_value() {
  setup_calls="${setup_calls}${1}=${2};"
  case "$1" in
    VSSBEPINEXENABLED) VSSBEPINEXENABLED="$2" ;;
    VSSPIPEPREEXISTING) VSSPIPEPREEXISTING="$2" ;;
  esac
}
TEST_SERVER_ACTIVE=0
TEST_PIPE_ACTIVE=0
TEST_PIPE_ENABLED=0
systemctl() {
  case "$1" in
    is-active)
      case "$3" in
        "$VHSERVERSERVICENAME") [[ "$TEST_SERVER_ACTIVE" -eq 1 ]] ;;
        "$VSSPIPESERVICENAME") [[ "$TEST_PIPE_ACTIVE" -eq 1 ]] ;;
        *) return 1 ;;
      esac
      ;;
    is-enabled)
      [[ "$TEST_PIPE_ENABLED" -eq 1 && "$3" == "$VSSPIPESERVICENAME" ]]
      ;;
    reset-failed) return 0 ;;
    *) return 0 ;;
  esac
}
sudo() {
  if [[ "$1" == systemctl ]]; then
    shift
    systemctl "$@"
  else
    command sudo "$@"
  fi
}
stop_valheim_service() {
  setup_calls="${setup_calls}stop;"
  if [[ "${BEPINEX_FAIL_STOP:-0}" == 1 ]]; then
    return 1
  fi
  TEST_SERVER_ACTIVE=0
}
start_valheim_service() {
  setup_calls="${setup_calls}start;"
  TEST_SERVER_ACTIVE=1
  [[ "${BEPINEX_FAIL_START:-0}" != 1 ]]
}
set_service() {
  setup_calls="${setup_calls}set:$1;"
  TEST_PIPE_ACTIVE=1
  TEST_PIPE_ENABLED=1
}
restart_vsspipe_service() { setup_calls="${setup_calls}restart:$VSSPIPESERVICENAME;"; }
uninstall_service() {
  setup_calls="${setup_calls}uninstall:$1;"
  TEST_PIPE_ACTIVE=0
  TEST_PIPE_ENABLED=0
}

if ! enable_bepinex_profile; then
  echo "FAIL: enabling BepInEx did not prepare the profile and pipe service" >&2
  exit 1
fi
if [[ "$setup_calls" != "VSSPIPEPREEXISTING=0;VSSBEPINEXENABLED=1;set:vss.pipe.UiWorld.service;" ]] ||
   [[ "$(cat "$BEPINEX_TEST_CALLS")" != 'install' ]]; then
  echo "FAIL: enabling BepInEx did not install and start the profile pipe service" >&2
  exit 1
fi
if [[ "$VSS_SETUP_NOTICE" != *'server remains stopped'* ]]; then
  echo "FAIL: BepInEx activation did not report that the stopped server remains stopped" >&2
  exit 1
fi

: > "$BEPINEX_TEST_CALLS"
setup_calls=''
TEST_SERVER_ACTIVE=1
TEST_PIPE_ACTIVE=1
if ! enable_bepinex_profile; then
  echo "FAIL: enabling BepInEx for a running server failed" >&2
  exit 1
fi
if [[ "$setup_calls" != "set:vss.pipe.UiWorld.service;restart:vss.pipe.UiWorld.service;" ]] ||
   [[ "$TEST_SERVER_ACTIVE" -ne 1 ]] ||
   [[ "$VSS_SETUP_NOTICE" != *'already enabled'* ]]; then
  echo "FAIL: repeated BepInEx activation did not preserve the running server state" >&2
  exit 1
fi

: > "$BEPINEX_TEST_CALLS"
setup_calls=''
export BEPINEX_FAIL_INSTALL=1
TEST_SERVER_ACTIVE=1
TEST_PIPE_ACTIVE=0
TEST_PIPE_ENABLED=0
VSSBEPINEXENABLED=0
VSSPIPEPREEXISTING=''
if enable_bepinex_profile; then
  echo "FAIL: BepInEx activation ignored a failed profile install" >&2
  exit 1
fi
if [[ "$setup_calls" != "stop;VSSPIPEPREEXISTING=0;VSSBEPINEXENABLED=1;VSSBEPINEXENABLED=0;uninstall:vss.pipe.UiWorld.service;start;" ]] ||
   [[ "$(cat "$BEPINEX_TEST_CALLS")" != $'install\nremove' ]] ||
   [[ "$TEST_SERVER_ACTIVE" -ne 1 ]]; then
  echo "FAIL: failed BepInEx activation did not restore the disabled running server" >&2
  exit 1
fi
unset BEPINEX_FAIL_INSTALL

: > "$BEPINEX_TEST_CALLS"
setup_calls=''
VSSPIPESERVICENAME='vss.pipe.NotInstalled.service'
TEST_SERVER_ACTIVE=0
if ! disable_bepinex_profile > "$TMPDIR_UI/bepinex-disable.out"; then
  echo "FAIL: disabling BepInEx returned an error" >&2
  exit 1
fi
if [[ "$setup_calls" != 'VSSBEPINEXENABLED=0;uninstall:vss.pipe.NotInstalled.service;VSSPIPEPREEXISTING=;' ]] ||
   [[ "$(cat "$BEPINEX_TEST_CALLS")" != 'remove' ]]; then
  echo "FAIL: disabling BepInEx did not retain the profile data while cleaning legacy links" >&2
  exit 1
fi

: > "$BEPINEX_TEST_CALLS"
setup_calls=''
VSSPIPESERVICENAME='vss.pipe.UiWorld.service'
VSSBEPINEXENABLED=0
VSSPIPEPREEXISTING=''
TEST_SERVER_ACTIVE=0
TEST_PIPE_ACTIVE=1
TEST_PIPE_ENABLED=1
if ! enable_bepinex_profile > "$TMPDIR_UI/bepinex-enable-existing-pipe.out"; then
  echo "FAIL: BepInEx activation failed with a pre-existing pipe service" >&2
  exit 1
fi
if [[ "$setup_calls" != "VSSPIPEPREEXISTING=1;VSSBEPINEXENABLED=1;set:vss.pipe.UiWorld.service;restart:vss.pipe.UiWorld.service;" ]] ||
   [[ "$VSSPIPEPREEXISTING" != 1 ]]; then
  echo "FAIL: BepInEx activation did not record the pre-existing pipe service" >&2
  exit 1
fi

: > "$BEPINEX_TEST_CALLS"
setup_calls=''
TEST_SERVER_ACTIVE=1
if ! disable_bepinex_profile > "$TMPDIR_UI/bepinex-disable-running.out"; then
  echo "FAIL: disabling BepInEx for a running server failed" >&2
  exit 1
fi
if [[ "$setup_calls" != "stop;VSSBEPINEXENABLED=0;set:vss.pipe.UiWorld.service;VSSPIPEPREEXISTING=;start;" ]] ||
   [[ "$TEST_SERVER_ACTIVE" -ne 1 ]] ||
   [[ "$TEST_PIPE_ACTIVE" -ne 1 ]] ||
   [[ "$VSS_SETUP_NOTICE" != *'pre-existing log pipe was kept'* ]] ||
   [[ "$(cat "$BEPINEX_TEST_CALLS")" != 'remove' ]]; then
  echo "FAIL: disabling BepInEx did not preserve the pre-existing pipe and restart the server in vanilla mode" >&2
  exit 1
fi

WEBHOOKURL='https://discord.example/secret-url'
setup_calls=''
secret_prompt_output="$(setup_value_prompt 'webhook URL' WEBHOOKURL <<< 'https://discord.example/new-secret')"
if [[ "$secret_prompt_output" != *'configured (hidden)'* ]] ||
   [[ "$secret_prompt_output" == *'secret-url'* ]] ||
   [[ "$secret_prompt_output" == *'new-secret'* ]]; then
  echo "FAIL: webhook credentials were displayed by setup_value_prompt" >&2
  exit 1
fi

CWD="$TMPDIR_UI"
mkdir -p "$CWD/lib"
cp "$ROOT/lib/config.sh" "$CWD/lib/config.sh"
printf 'VHSERVERWORLD=UiWorld\n' > "$CWD/.env.UiWorld"
printf 'VHSERVERWORLD=OtherWorld\n' > "$CWD/.env.OtherWorld"
VSS_SERVER_NAME=''
if ! select_server_profile <<< 'OtherWorld' > "$TMPDIR_UI/picker.out"; then
  echo "FAIL: profile picker did not accept a listed profile name" >&2
  exit 1
fi
if [ "$SELECTED_SERVER_PROFILE" != 'OtherWorld' ]; then
  echo "FAIL: profile picker selected the wrong profile" >&2
  exit 1
fi
if ! grep -Fq 'Which server profile do you want to select?' "$TMPDIR_UI/picker.out" ||
   ! grep -Fq 'Choice:' "$TMPDIR_UI/picker.out"; then
  echo "FAIL: profile picker prompt was not visible on stdout" >&2
  exit 1
fi
profile_question_line="$(grep -n -F 'Which server profile do you want to select?' "$TMPDIR_UI/picker.out" | cut -d: -f1)"
profile_input_line="$(grep -n -F 'Choice:' "$TMPDIR_UI/picker.out" | cut -d: -f1)"
if [ "$profile_question_line" -ge "$profile_input_line" ]; then
  echo "FAIL: profile picker question was not shown above the input prompt" >&2
  exit 1
fi
if ! grep -Fq 'PROFILES OVERVIEW' "$TMPDIR_UI/picker.out"; then
  echo "FAIL: profile picker did not show the profile overview" >&2
  exit 1
fi
if ! select_server_profile <<< '1' > "$TMPDIR_UI/picker-number.out" ||
   [ "$SELECTED_SERVER_PROFILE" != 'OtherWorld' ]; then
  echo "FAIL: profile picker did not accept a numeric profile selection" >&2
  exit 1
fi
cat > "$TMPDIR_UI/keyboard-profile.sh" <<EOF
source "$ROOT/setup" >/dev/null
CWD="$TMPDIR_UI"
VSS_SERVER_NAME=''
select_server_profile
printf 'KEYBOARD_PROFILE=%s\\n' "\$SELECTED_SERVER_PROFILE"
EOF
keyboard_profile_output="$(printf '\033[B\n' | script -qec "bash '$TMPDIR_UI/keyboard-profile.sh'" /dev/null)"
if [[ "$keyboard_profile_output" != *'KEYBOARD_PROFILE=UiWorld'* ||
      "$keyboard_profile_output" != *$'\033[7m   2  UiWorld\033[0m'* ]]; then
  echo "FAIL: down-arrow navigation did not select the next server profile" >&2
  exit 1
fi

picker_output="$(printf 'n\n../invalid\nq\n' | select_server_profile || true)"
if [[ "$picker_output" != *'Invalid world name.'* ]]; then
  echo "FAIL: profile picker did not show an invalid-name message" >&2
  exit 1
fi

VSS_SERVER_NAME='CurrentWorld'
VHSERVERWORLD='CurrentWorld'
load_server_profile_unchecked() {
  VSS_SERVER_NAME="$1"
  VHSERVERWORLD="$1"
  [[ "$1" != 'BrokenWorld' ]]
}
if load_server_profile BrokenWorld >/dev/null 2>&1; then
  echo "FAIL: invalid profile load unexpectedly succeeded" >&2
  exit 1
fi
if [[ "$VSS_SERVER_NAME" != 'CurrentWorld' || "$VHSERVERWORLD" != 'CurrentWorld' ]]; then
  echo "FAIL: failed profile load did not restore the previous active profile" >&2
  exit 1
fi

PROFILE_CREATE_DIR="$TMPDIR_UI/profile-create"
mkdir -p "$PROFILE_CREATE_DIR/examples" "$PROFILE_CREATE_DIR/launcher"
cp "$ROOT/.env.server.dist" "$PROFILE_CREATE_DIR/.env.server.dist"
cp "$ROOT/examples/launcher-args" "$PROFILE_CREATE_DIR/examples/launcher-args"
CWD="$PROFILE_CREATE_DIR"
validate_server_profile_ports() { return 0; }
write_env_value() {
  [[ "$2" != 'STATUSPORT' ]] || return 1
  printf '%s=%s\n' "$2" "$3" >> "$1"
}
if create_server_profile IncompleteWorld > "$TMPDIR_UI/profile-create.out" 2>&1; then
  echo "FAIL: profile creation ignored a failed configuration write" >&2
  exit 1
fi
if [[ -e "$PROFILE_CREATE_DIR/.env.IncompleteWorld" ||
      -e "$PROFILE_CREATE_DIR/launcher/launcher-args.IncompleteWorld" ]]; then
  echo "FAIL: failed profile creation left partial profile files behind" >&2
  exit 1
fi

VSS_SERVER_NAME='UiWorld'
VHSERVERWORLD='UiWorld'
VHSERVERSERVICENAME='valheim-server.UiWorld.service'
VHSERVERSAVEDIR="$TMPDIR_UI/world-saves"
mkdir -p "$VHSERVERSAVEDIR/worlds_local"
touch "$VHSERVERSAVEDIR/worlds_local/UiWorld.fwl" \
  "$VHSERVERSAVEDIR/worlds_local/UiWorld.db" \
  "$VHSERVERSAVEDIR/worlds_local/UiWorld_backup.fwl" \
  "$VHSERVERSAVEDIR/worlds_local/OtherWorld.db"
TEST_SERVER_ACTIVE=0
if ! reset_profile_world <<< 'no' >/dev/null; then
  echo "FAIL: cancelling a world reset returned an error" >&2
  exit 1
fi
if [[ ! -f "$VHSERVERSAVEDIR/worlds_local/UiWorld.fwl" ]]; then
  echo "FAIL: cancelling a world reset changed save files" >&2
  exit 1
fi

TEST_SERVER_ACTIVE=1
if ! reset_profile_world <<< 'DELETE WORLD' >/dev/null; then
  echo "FAIL: confirmed world reset failed" >&2
  exit 1
fi
if [[ -e "$VHSERVERSAVEDIR/worlds_local/UiWorld.fwl" ||
      -e "$VHSERVERSAVEDIR/worlds_local/UiWorld.db" ||
      -e "$VHSERVERSAVEDIR/worlds_local/UiWorld_backup.fwl" ||
      ! -f "$VHSERVERSAVEDIR/worlds_local/OtherWorld.db" ||
      "$TEST_SERVER_ACTIVE" -ne 1 ||
      "$VSS_SETUP_NOTICE" != *'server was restarted'* ]]; then
  echo "FAIL: world reset did not safely delete only the selected world and restore service state" >&2
  exit 1
fi

touch "$VHSERVERSAVEDIR/worlds_local/UiWorld.fwl"
TEST_SERVER_ACTIVE=1
export BEPINEX_FAIL_STOP=1
if reset_profile_world <<< 'DELETE WORLD' >/dev/null 2>&1; then
  echo "FAIL: world reset ignored a server stop failure" >&2
  exit 1
fi
if [[ ! -f "$VHSERVERSAVEDIR/worlds_local/UiWorld.fwl" ]]; then
  echo "FAIL: world reset deleted save files after a stop failure" >&2
  exit 1
fi
unset BEPINEX_FAIL_STOP

echo "interactive setup UI OK"
