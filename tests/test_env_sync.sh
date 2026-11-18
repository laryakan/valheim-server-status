#!/bin/bash
set -u

cd "$(dirname "$0")/.."
export DEBUGMODE=1

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

source ./setup >/dev/null

if ! declare -F ensure_env_sync >/dev/null 2>&1; then
  echo "FAIL: ensure_env_sync function should exist" >&2
  exit 1
fi

TEST_ENV="$TEST_DIR/.env.test_sync"
cp .env.dist "$TEST_ENV"
sed -i '/^VHSERVERSEED=/d' "$TEST_ENV"

ensure_env_sync "$TEST_ENV" .env.dist

if ! grep -q '^VHSERVERSEED=' "$TEST_ENV"; then
  echo "FAIL: VHSERVERSEED was not restored to the env file" >&2
  exit 1
fi

echo "env sync OK"
