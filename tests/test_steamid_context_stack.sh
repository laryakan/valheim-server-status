#!/bin/bash
set -u

cd "$(dirname "$0")/.."

cp .env.dist .env
rm -f .env.test_steamid_context

export EVENTREALTIME=0
export STEAMIDMAPFILE="$PWD/data/steamid-player-map"
export LAST_WORLD_SAVE_FILE="$PWD/data/last-world-save"

printf '%s\n' \
"09/09/2026 21:16:21: Got connection SteamID from 76561198000000001" \
"09/09/2026 21:16:21: Got character ZDOID from UnBonhomeTeSt : 12345:9" \
| bash ./vss.log-filter >/dev/null 2>&1

if ! grep -q '^76561198000000001;UnBonhomeTeSt$' "$STEAMIDMAPFILE"; then
  echo "FAIL: SteamID context stack did not persist from SteamID line to ZDOID line" >&2
  exit 1
fi

echo "steamid context stack OK"
