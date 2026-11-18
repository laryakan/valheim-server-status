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
expected_removal_calls="cron:UiWorld;$VHSERVERSERVICENAME;$VSSHTTPSERVICENAME;$VSSPIPESERVICENAME;"
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
replace_env_value() { setup_calls="${setup_calls}${1}=${2};"; }
set_service() { setup_calls="${setup_calls}set:$1;"; }
restart_vsspipe_service() { setup_calls="${setup_calls}restart:$VSSPIPESERVICENAME;"; }

if ! enable_bepinex_profile; then
  echo "FAIL: enabling BepInEx did not prepare the profile and pipe service" >&2
  exit 1
fi
if [[ "$setup_calls" != "VSSBEPINEXENABLED=1;set:vss.pipe.UiWorld.service;restart:vss.pipe.UiWorld.service;" ]] ||
   [[ "$(cat "$BEPINEX_TEST_CALLS")" != 'install' ]]; then
  echo "FAIL: enabling BepInEx did not install and restart the profile pipe service" >&2
  exit 1
fi

: > "$BEPINEX_TEST_CALLS"
setup_calls=''
export BEPINEX_FAIL_INSTALL=1
if enable_bepinex_profile; then
  echo "FAIL: BepInEx activation ignored a failed profile install" >&2
  exit 1
fi
if [[ "$setup_calls" != "VSSBEPINEXENABLED=1;VSSBEPINEXENABLED=0;" ]] ||
   [[ "$(cat "$BEPINEX_TEST_CALLS")" != 'install' ]]; then
  echo "FAIL: failed BepInEx activation did not roll back its profile flag" >&2
  exit 1
fi
unset BEPINEX_FAIL_INSTALL

: > "$BEPINEX_TEST_CALLS"
setup_calls=''
VSSPIPESERVICENAME='vss.pipe.NotInstalled.service'
if ! disable_bepinex_profile > "$TMPDIR_UI/bepinex-disable.out"; then
  echo "FAIL: disabling BepInEx returned an error" >&2
  exit 1
fi
if [[ "$setup_calls" != 'VSSBEPINEXENABLED=0;' ]] ||
   [[ "$(cat "$BEPINEX_TEST_CALLS")" != 'remove' ]]; then
  echo "FAIL: disabling BepInEx did not retain the profile data while cleaning legacy links" >&2
  exit 1
fi

CWD="$TMPDIR_UI"
touch "$CWD/.env.UiWorld"
touch "$CWD/.env.OtherWorld"
VSS_SERVER_NAME=''
if ! select_server_profile <<< 'OtherWorld' > "$TMPDIR_UI/picker.out"; then
  echo "FAIL: profile picker did not accept a listed profile name" >&2
  exit 1
fi
if [ "$SELECTED_SERVER_PROFILE" != 'OtherWorld' ]; then
  echo "FAIL: profile picker selected the wrong profile" >&2
  exit 1
fi
if ! grep -Fq 'Profile name or choice:' "$TMPDIR_UI/picker.out"; then
  echo "FAIL: profile picker prompt was not visible on stdout" >&2
  exit 1
fi

picker_output="$(printf 'n\n../invalid\nq\n' | select_server_profile || true)"
if [[ "$picker_output" != *'Invalid world name.'* ]]; then
  echo "FAIL: profile picker did not show an invalid-name message" >&2
  exit 1
fi

echo "interactive setup UI OK"
