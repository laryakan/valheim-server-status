#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_STATUS="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_STATUS"' EXIT

mkdir -p "$TMPDIR_STATUS"/{status,lib,data,launcher}
cp "$ROOT/status/server-status" "$TMPDIR_STATUS/status/"
cp "$ROOT/lib/config.sh" "$ROOT/lib/validation.sh" "$TMPDIR_STATUS/lib/"
cp "$ROOT/i18n.sh" "$TMPDIR_STATUS/"

cat > "$TMPDIR_STATUS/.env.StatusTest" <<EOF
VSSDIR="$TMPDIR_STATUS"
VHSERVERWORLD=StatusTest
VSSBEPINEXENABLED=1
R2MODMANCODE=01a1eaf3-9be3-9083-b9b4-26768368368e
BEPINEXVERSION=5.4.2202
BEPINEXLASTUPDATE=2026-01-01
VALSERVERVERSION=0.221.0
VALSERVERLASTUPDATE=2026-01-01
VHSERVERSEED=InformationalSeed
LASTWORLDSAVEFILE="$TMPDIR_STATUS/data/last-world-save"
CONNECTEDPLAYERSFILE="$TMPDIR_STATUS/data/online-players"
OFFLINEPLAYERSFILE="$TMPDIR_STATUS/data/offline-players"
VHSERVERLAUNCHERARGS="$TMPDIR_STATUS/launcher/launcher-args.StatusTest"
EOF
printf '%s\n' 'unknown' > "$TMPDIR_STATUS/data/last-world-save"
touch "$TMPDIR_STATUS/data/online-players" "$TMPDIR_STATUS/data/offline-players"
touch "$TMPDIR_STATUS/launcher/launcher-args.StatusTest"

if ! VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" --for-webhook \
  > "$TMPDIR_STATUS/webhook-enabled.out"; then
  cat "$TMPDIR_STATUS/crash.log" >&2
  echo "FAIL: status webhook output failed with BepInEx enabled" >&2
  exit 1
fi
if ! grep -Fq 'R2Modman code' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq '01a1eaf3-9be3-9083-b9b4-26768368368e' "$TMPDIR_STATUS/webhook-enabled.out"; then
  echo "FAIL: enabled BepInEx status did not include the R2Modman code" >&2
  exit 1
fi

if VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" \
  > "$TMPDIR_STATUS/status-enabled.out" 2>&1; then
  echo "FAIL: offline text status returned success" >&2
  exit 1
fi
if ! grep -Fq 'R2Modman profile code' "$TMPDIR_STATUS/status-enabled.out" ||
   ! grep -Fq '01a1eaf3-9be3-9083-b9b4-26768368368e' "$TMPDIR_STATUS/status-enabled.out"; then
  echo "FAIL: offline status output did not include the R2Modman code" >&2
  exit 1
fi

sed -i 's/^R2MODMANCODE=.*/R2MODMANCODE=not-a-uuid/' "$TMPDIR_STATUS/.env.StatusTest"
if ! VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" --for-webhook \
  > "$TMPDIR_STATUS/webhook-invalid.out"; then
  echo "FAIL: status webhook output failed with an invalid R2Modman code" >&2
  exit 1
fi
if grep -Fq 'R2Modman code' "$TMPDIR_STATUS/webhook-invalid.out" ||
   ! grep -Fq 'R2MODMANCODE must be a UUID' "$TMPDIR_STATUS/crash.log"; then
  echo "FAIL: invalid R2Modman code was not safely omitted and reported" >&2
  exit 1
fi

sed -i 's/^VSSBEPINEXENABLED=1$/VSSBEPINEXENABLED=0/' "$TMPDIR_STATUS/.env.StatusTest"
if ! VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" --for-webhook \
  > "$TMPDIR_STATUS/webhook-disabled.out"; then
  echo "FAIL: status webhook output failed with BepInEx disabled" >&2
  exit 1
fi
if grep -Fq 'R2Modman code' "$TMPDIR_STATUS/webhook-disabled.out" ||
   grep -Fq '01a1eaf3-9be3-9083-b9b4-26768368368e' "$TMPDIR_STATUS/webhook-disabled.out"; then
  echo "FAIL: R2Modman code was exposed while BepInEx was disabled" >&2
  exit 1
fi

echo "R2Modman status display OK"
