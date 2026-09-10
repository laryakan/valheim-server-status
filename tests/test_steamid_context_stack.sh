#!/bin/bash
set -u

cd "$(dirname "$0")/.."

cd "$(dirname "$0")/.."
export DEBUGMODE=1

printf '%s\n' \
"09/09/2026 21:16:21: Got connection SteamID 76561198000000001" \
"09/09/2026 21:16:21: Got character ZDOID from UnBonhomeTeSt : 12345:9" \
| bash ./vss.log-filter

if ! grep -q '^76561198000000001;UnBonhomeTeSt$' "$STEAMIDMAPFILE"; then
  echo "FAIL: SteamID context stack did not persist from SteamID line to ZDOID line" >&2
  exit 1
fi

echo "steamid context stack OK"
