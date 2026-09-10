#!/bin/bash
set -u

cd "$(dirname "$0")/.."

if ! grep -q "sed -i '/^\$/d' \"\$CONNECTEDPLAYERSFILE\"" vss.log-filter; then
  echo "FAIL: vss.log-filter should remove blank lines from CONNECTEDPLAYERSFILE" >&2
  exit 1
fi

if ! grep -q "sed -i '/^\$/d' \"\$OFFLINEPLAYERSFILE\"" vss.log-filter; then
  echo "FAIL: vss.log-filter should remove blank lines from OFFLINEPLAYERSFILE" >&2
  exit 1
fi

if ! grep -q "awk -F';' 'NF >= 3 && \$2 != \"\" { print \$2 }' \"\$CONNECTEDPLAYERSFILE\"" status/server-status; then
  echo "FAIL: server-status should serialize only non-empty player names from the connected list" >&2
  exit 1
fi

if ! grep -q "awk -F';' 'NF >= 3 && \$2 != \"\" { print \$2 }' \"\$OFFLINEPLAYERSFILE\"" status/server-status; then
  echo "FAIL: server-status should serialize only non-empty player names from the offline list" >&2
  exit 1
fi

echo "player list sanitization regression OK"
