#!/bin/bash
set -u

cd "$(dirname "$0")/.."

source ./setup >/dev/null 2>&1

if ! declare -F ensure_env_sync >/dev/null 2>&1; then
  echo "FAIL: ensure_env_sync function should exist" >&2
  exit 1
fi

cp .env.dist .env.test_sync
sed -i '/^VHSERVERSEED=/d' .env.test_sync

ensure_env_sync .env.test_sync .env.dist

if ! grep -q '^VHSERVERSEED=' .env.test_sync; then
  echo "FAIL: VHSERVERSEED was not restored to the env file" >&2
  exit 1
fi

rm -f .env.test_sync

echo "env sync OK"
