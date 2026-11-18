#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_PROFILE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PROFILE"' EXIT
cd "$ROOT"
source ./setup >/dev/null
cp "$ROOT/.env.test" "$TMPDIR_PROFILE/config.env"
export VSS_ENV_FILE="$TMPDIR_PROFILE/config.env"
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
  if [ "$service" = "$VHSERVERSERVICENAME" ] &&
     grep -q '^ExecStartPre=' "$CWD/systemd/$service"; then
    echo "FAIL: Valheim service still updates shared server files on individual startup" >&2
    exit 1
  fi
done

echo "profile-specific service templates OK"
