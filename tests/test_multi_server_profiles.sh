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

echo "multi-server profile isolation OK"
