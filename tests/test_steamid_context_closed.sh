#!/bin/bash
set -u

cd "$(dirname "$0")/.."

cp .env.dist .env

export EVENTREALTIME=0
export STEAMIDMAPFILE="$PWD/data/steamid-player-map"
export LAST_WORLD_SAVE_FILE="$PWD/data/last-world-save"

printf '%s\n' \
"09/09/2026 21:16:21: Got connection SteamID from 76561198000000001" \
"09/09/2026 21:16:21: Got character ZDOID from UnBonhomeTeSt : 12345:9" \
"09/09/2026 21:16:21: Got character ZDOID from AnotherPlayer : 54321:8" \
| bash ./vss.log-filter >/dev/null 2>&1

if grep -q '^76561198000000001;UnBonhomeTeSt$' "$STEAMIDMAPFILE" && grep -q '^76561198000000001;AnotherPlayer$' "$STEAMIDMAPFILE"; then
  echo "FAIL: stale SteamID context leaked into a new ZDOID mapping after the first map closure" >&2
  exit 1
fi

echo "steamid context closure OK"
