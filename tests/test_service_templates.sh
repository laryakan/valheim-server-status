#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_PROFILE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PROFILE"' EXIT
cd "$ROOT"
source ./setup >/dev/null
source .env.test
export VSS_ENV_FILE="$ROOT/.env.test"
source ./lib/config.sh
vss_load_config "$ROOT"
CWD="$TMPDIR_PROFILE"
mkdir -p "$CWD/examples" "$CWD/systemd"
cp "$ROOT/examples/valheim-server.service" "$CWD/examples/"
cp "$ROOT/examples/vss.http.service" "$CWD/examples/"
cp "$ROOT/examples/vss.pipe.service" "$CWD/examples/"

for service in "$VHSERVERSERVICENAME" "$VSSHTTPSERVICENAME" "$VSSPIPESERVICENAME"; do
  if ! render_service "$service"; then
    echo "FAIL: could not render $service" >&2
    exit 1
  fi
  if grep -q '###.*###' "$CWD/systemd/$service"; then
    echo "FAIL: unresolved placeholder in $service" >&2
    exit 1
  fi
  if ! grep -Fq "Environment=VSS_SERVER_NAME=$VSS_SERVER_NAME" "$CWD/systemd/$service"; then
    echo "FAIL: $service does not select its server profile" >&2
    exit 1
  fi
done

echo "profile-specific service templates OK"
