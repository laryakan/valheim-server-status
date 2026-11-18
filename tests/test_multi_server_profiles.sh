#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_PROFILE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PROFILE"' EXIT

create_profile_config() {
  local name="$1"
  cat > "$TMPDIR_PROFILE/.env.$name" <<EOF
VSSDIR="$TMPDIR_PROFILE"
VHSERVERWORLD="$name"
CONNECTEDPLAYERSFILE="\$VSSDIR/data/online-players.$name"
OFFLINEPLAYERSFILE="\$VSSDIR/data/offline-players.$name"
STEAMIDMAPFILE="\$VSSDIR/data/steamid-player-map.$name"
LASTWORLDSAVEFILE="\$VSSDIR/data/last-world-save.$name"
VALHEIMSERVERLOGDIR="\$VSSDIR/valheim-logs.d"
VALHEIMSERVERLOGPATH="\$VALHEIMSERVERLOGDIR/*.$name.*.log"
EOF
}

create_profile_config Alpha
create_profile_config Beta
create_profile_config Alpha.env.World

load_profile() (
  VSS_SERVER_NAME="$1"
  export VSS_SERVER_NAME
  unset VSS_ENV_FILE VSS_CONFIG_LOADED
  source "$ROOT/lib/config.sh"
  vss_load_config "$TMPDIR_PROFILE"
  printf '%s|%s|%s\n' "$CONNECTEDPLAYERSFILE" "$STEAMIDMAPFILE" "$VALHEIMSERVERLOGPATH"
)

ALPHA="$(load_profile Alpha)"
BETA="$(load_profile Beta)"

if [ "$ALPHA" = "$BETA" ]; then
  echo "FAIL: profiles resolved to identical state and log paths" >&2
  exit 1
fi

case "$ALPHA" in
  *online-players.Alpha*steamid-player-map.Alpha*'*.Alpha.*.log'*) ;;
  *) echo "FAIL: Alpha paths do not include the profile name" >&2; exit 1 ;;
esac
case "$BETA" in
  *online-players.Beta*steamid-player-map.Beta*'*.Beta.*.log'*) ;;
  *) echo "FAIL: Beta paths do not include the profile name" >&2; exit 1 ;;
esac
PROFILE_WITH_ENV_SUBSTRING="$(load_profile Alpha.env.World)"
case "$PROFILE_WITH_ENV_SUBSTRING" in
  *online-players.Alpha.env.World*steamid-player-map.Alpha.env.World*)
    ;;
  *)
    echo "FAIL: profile names containing '.env.' were not resolved from the filename basename" >&2
    exit 1
    ;;
esac

create_profile_config FixedState
sed -i "s|^CONNECTEDPLAYERSFILE=.*|CONNECTEDPLAYERSFILE=\"$TMPDIR_PROFILE/custom-online-players\"|" \
  "$TMPDIR_PROFILE/.env.FixedState"
FIXED_STATE_PATHS="$(load_profile FixedState)"
case "$FIXED_STATE_PATHS" in
  *"$TMPDIR_PROFILE/data/online-players.FixedState"*) ;;
  *) echo "FAIL: profile could override the fixed VSS state location" >&2; exit 1 ;;
esac
touch "$TMPDIR_PROFILE/custom-online-players"
if (
  VSS_SERVER_NAME=FixedState
  export VSS_SERVER_NAME
  unset VSS_ENV_FILE VSS_CONFIG_LOADED
  source "$ROOT/lib/config.sh"
  vss_load_config "$TMPDIR_PROFILE"
); then
  echo "FAIL: profile with an existing custom state file was silently redirected" >&2
  exit 1
fi

cat > "$TMPDIR_PROFILE/.env.test" <<'EOF'
VSS_SERVER_NAME='server.world'
VHSERVERWORLD='server.world'
EOF
if (
  VSS_SERVER_NAME=test
  VSS_ENV_FILE="$TMPDIR_PROFILE/.env.test"
  export VSS_SERVER_NAME VSS_ENV_FILE
  unset VSS_CONFIG_LOADED
  source "$ROOT/lib/config.sh"
  vss_load_config "$TMPDIR_PROFILE"
); then
  echo "FAIL: .env.test was allowed to load as a different profile" >&2
  exit 1
fi

if (
  VSS_SERVER_NAME="../outside"
  export VSS_SERVER_NAME
  unset VSS_ENV_FILE VSS_CONFIG_LOADED
  source "$ROOT/lib/config.sh"
  vss_load_config "$TMPDIR_PROFILE"
); then
  echo "FAIL: invalid profile names should be rejected" >&2
  exit 1
fi

if (
  unset VSS_SERVER_NAME VSS_ENV_FILE VSS_CONFIG_LOADED
  source "$ROOT/lib/config.sh"
  vss_load_config "$TMPDIR_PROFILE"
); then
  echo "FAIL: config loading should require an explicit profile" >&2
  exit 1
fi

cat > "$TMPDIR_PROFILE/.env" <<EOF
VSS_COMMON_CONFIG_VERSION=3
VSSDIR="$TMPDIR_PROFILE"
VALHEIMSERVERLOGDIR="$TMPDIR_PROFILE/shared-logs"
PUBLICIP='203.0.113.8'
EOF
SHARED_CONFIG="$(load_profile Alpha)"
case "$SHARED_CONFIG" in
  *"$TMPDIR_PROFILE/data/online-players.Alpha"*) ;;
  *) echo "FAIL: common config changed profile-specific state paths" >&2; exit 1 ;;
esac
(
  VSS_SERVER_NAME=Alpha
  export VSS_SERVER_NAME
  unset VSS_ENV_FILE VSS_CONFIG_LOADED
  source "$ROOT/lib/config.sh"
  vss_load_config "$TMPDIR_PROFILE"
  [ "$VSSDIR" = "$TMPDIR_PROFILE" ] ||
    { echo "FAIL: VSSDIR was not shared from the installation root" >&2; exit 1; }
  [ "$VALHEIMSERVERLOGDIR" = "$TMPDIR_PROFILE/shared-logs" ] ||
    { echo "FAIL: shared log directory did not override profile configuration" >&2; exit 1; }
  [ "$VALHEIMSERVERLOGPATH" = "$TMPDIR_PROFILE/shared-logs/*.Alpha.*.log" ] ||
    { echo "FAIL: default log path was not recalculated from shared settings" >&2; exit 1; }
  [ "$STATUSURL" = 'http://203.0.113.8:8181/' ] ||
    { echo "FAIL: default status URL was not recalculated from shared PUBLICIP" >&2; exit 1; }
)

load_bepinex_profile() (
  VSS_SERVER_NAME="$1"
  export VSS_SERVER_NAME
  unset VSS_ENV_FILE VSS_CONFIG_LOADED
  source "$ROOT/lib/config.sh"
  vss_load_config "$TMPDIR_PROFILE"
  printf '%s|%s\n' "$VSSBEPINEXDIR" "$VSSBEPINEXLOGOUTPUT"
)

ALPHA_BEPINEX="$(load_bepinex_profile Alpha)"
BETA_BEPINEX="$(load_bepinex_profile Beta)"
if [ "$ALPHA_BEPINEX" = "$BETA_BEPINEX" ]; then
  echo "FAIL: BepInEx profile roots and logs were shared" >&2
  exit 1
fi
case "$ALPHA_BEPINEX" in
  "$TMPDIR_PROFILE/bepinex/profiles/Alpha|$TMPDIR_PROFILE/bepinex/profiles/Alpha/BepInEx/LogOutput.log") ;;
  *) echo "FAIL: Alpha BepInEx paths do not use its profile root" >&2; exit 1 ;;
esac
case "$BETA_BEPINEX" in
  "$TMPDIR_PROFILE/bepinex/profiles/Beta|$TMPDIR_PROFILE/bepinex/profiles/Beta/BepInEx/LogOutput.log") ;;
  *) echo "FAIL: Beta BepInEx paths do not use its profile root" >&2; exit 1 ;;
esac

cat >> "$TMPDIR_PROFILE/.env.Alpha" <<'EOF'
VSSBEPINEXDIR="$VSSDIR/bepinex/current/"
VSSBEPINEXLOGOUTPUT="$VSSBEPINEXDIR/BepInEx/LogOutput.log"
EOF
LEGACY_BEPINEX="$(load_bepinex_profile Alpha)"
case "$LEGACY_BEPINEX" in
  "$TMPDIR_PROFILE/bepinex/profiles/Alpha|$TMPDIR_PROFILE/bepinex/profiles/Alpha/BepInEx/LogOutput.log") ;;
  *) echo "FAIL: legacy shared BepInEx paths were not mapped to the profile" >&2; exit 1 ;;
esac

echo "multi-server profile isolation OK"
