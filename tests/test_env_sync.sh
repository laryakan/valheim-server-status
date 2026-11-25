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
cp .env.server.dist "$TEST_ENV"
sed -i '/^VHSERVERSEED=/d' "$TEST_ENV"

ensure_env_sync "$TEST_ENV" .env.server.dist

if ! grep -q '^VHSERVERSEED=' "$TEST_ENV"; then
  echo "FAIL: VHSERVERSEED was not restored to the env file" >&2
  exit 1
fi

source ./lib/config.sh
CWD="$TEST_DIR"
cp .env.common.dist "$CWD/.env.common.dist"
cp .env.common.dist "$CWD/.env"
sed -i '/^VSS_LANG=/d; /^VSSSTEAMBRANCH=/d' "$CWD/.env"
ensure_common_config
if ! grep -q '^VSS_LANG=' "$CWD/.env"; then
  echo "FAIL: shared configuration did not synchronize new template settings" >&2
  exit 1
fi
if ! grep -Fxq 'VSSSTEAMBRANCH=default_old' "$CWD/.env"; then
  echo "FAIL: shared configuration did not add the default Steam branch" >&2
  exit 1
fi
write_env_value "$CWD/.env" VSSSTEAMBRANCH public
ensure_common_config
if ! grep -Fxq 'VSSSTEAMBRANCH=public' "$CWD/.env"; then
  echo "FAIL: shared configuration overwrote the configured Steam branch" >&2
  exit 1
fi

VALUE_ENV="$TEST_DIR/value.env"
printf "VALUE=''\n" > "$VALUE_ENV"
write_env_value "$VALUE_ENV" VALUE "$TEST_DIR/*.log path"
(
  source "$VALUE_ENV"
  [ "$VALUE" = "$TEST_DIR/*.log path" ] || {
    echo "FAIL: write_env_value did not preserve shell-special characters" >&2
    exit 1
  }
)

INIT_DIR="$TEST_DIR/common-init"
mkdir -p "$INIT_DIR/lib"
cp lib/config.sh "$INIT_DIR/lib/config.sh"
cp .env.server.dist "$INIT_DIR/.env.server.dist"
cp .env.common.dist "$INIT_DIR/.env.common.dist"
cp .env.server.dist "$INIT_DIR/.env.SyncWorld"
write_env_value "$INIT_DIR/.env.SyncWorld" VHSERVERWORLD SyncWorld
write_env_value "$INIT_DIR/.env.SyncWorld" VSSLOGFILTER "$TEST_DIR/custom-log-filter"
write_env_value "$INIT_DIR/.env.SyncWorld" WEBHOOKURL 'https://discord.example/webhook'
CWD="$INIT_DIR"
VSS_SERVER_NAME=SyncWorld
VSS_ENV_FILE="$CWD/.env.SyncWorld"
unset VSS_CONFIG_LOADED
source "$CWD/lib/config.sh"
vss_load_config "$CWD"
ensure_common_config
(
  VSS_CONFIG_LOADED=0
  vss_load_config "$CWD"
  [ "$VSSLOGFILTER" = "$TEST_DIR/custom-log-filter" ] || {
    echo "FAIL: first shared configuration discarded the existing log filter path" >&2
    exit 1
  }
  [ "$WEBHOOKURL" = 'https://discord.example/webhook' ] || {
    echo "FAIL: first shared configuration discarded the existing webhook URL" >&2
    exit 1
  }
)

echo "env sync OK"
