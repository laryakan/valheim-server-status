#!/bin/bash
set -u

cd "$(dirname "$0")/.."

TEST_STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_STATE_DIR"' EXIT
export DEBUGMODE=1
export VSS_ENV_FILE="$PWD/.env.test"
source ./lib/config.sh
vss_load_config "$PWD"
CONNECTEDPLAYERSFILE="$TEST_STATE_DIR/online-players.$VSS_SERVER_NAME"
OFFLINEPLAYERSFILE="$TEST_STATE_DIR/offline-players.$VSS_SERVER_NAME"
STEAMIDMAPFILE="$TEST_STATE_DIR/steamid-player-map.$VSS_SERVER_NAME"
LASTWORLDSAVEFILE="$TEST_STATE_DIR/last-world-save.$VSS_SERVER_NAME"
VALHEIMSERVERLOGDIR="$TEST_STATE_DIR/valheim-logs.d"
export CONNECTEDPLAYERSFILE OFFLINEPLAYERSFILE STEAMIDMAPFILE LASTWORLDSAVEFILE VALHEIMSERVERLOGDIR

printf '%s\n' \
"09/09/2026 21:16:21: Got connection SteamID 76561198000000001" \
"09/09/2026 21:16:21: Got character ZDOID from UnBonhomeTeSt : 12345:9" \
| bash ./vss.log-filter

if ! grep -q '^76561198000000001;UnBonhomeTeSt$' "$STEAMIDMAPFILE"; then
  echo "FAIL: SteamID context stack did not persist from SteamID line to ZDOID line" >&2
  exit 1
fi

echo "steamid context stack OK"
