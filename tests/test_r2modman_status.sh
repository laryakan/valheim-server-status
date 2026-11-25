#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_STATUS="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_STATUS"' EXIT

mkdir -p "$TMPDIR_STATUS"/{status,lib,data,launcher,bin}
mkdir -p "$TMPDIR_STATUS/logs"
cp "$ROOT/status/server-status" "$TMPDIR_STATUS/status/"
cp "$ROOT/lib/config.sh" "$ROOT/lib/validation.sh" "$TMPDIR_STATUS/lib/"
cp "$ROOT/i18n.sh" "$TMPDIR_STATUS/"
cat > "$TMPDIR_STATUS/bin/systemctl" <<'EOF'
#!/bin/bash
if [ "$1" != show ] || [ "$2" != 'valheim-server.StatusTest.service' ]; then
  printf 'Unexpected systemctl request: %s\n' "$*" >&2
  exit 1
fi
printf 'LoadState=loaded\nActiveState=%s\nActiveEnterTimestamp=%s\n' \
  "${MOCK_SERVICE_STATE:-inactive}" "${MOCK_SERVICE_STARTED:-}"
EOF
chmod +x "$TMPDIR_STATUS/bin/systemctl"
export PATH="$TMPDIR_STATUS/bin:$PATH"

cat > "$TMPDIR_STATUS/.env.StatusTest" <<EOF
VSSDIR="$TMPDIR_STATUS"
VHSERVERWORLD=StatusTest
VHSERVERNAME='DisplayWorld'
VHSERVERPORT=2456
VHSERVERPASSWD='test-password'
PUBLICIP=203.0.113.1
SENDSERVERCONNECTIONINFO=1
SENDLASTLOGS=2
VALHEIMSERVERLOGPATH="$TMPDIR_STATUS/logs/*.log"
VSSBEPINEXENABLED=1
R2MODMANCODE=01a1eaf3-9be3-9083-b9b4-26768368368e
BEPINEXVERSION=5.4.2202
BEPINEXLASTUPDATE=2026-01-01
VALSERVERVERSION=0.221.0
VALSERVERLASTUPDATE=2026-01-01
VHSERVERSEED=InformationalSeed
LASTWORLDSAVEFILE="$TMPDIR_STATUS/data/last-world-save.StatusTest"
CONNECTEDPLAYERSFILE="$TMPDIR_STATUS/data/online-players.StatusTest"
OFFLINEPLAYERSFILE="$TMPDIR_STATUS/data/offline-players.StatusTest"
VHSERVERLAUNCHERARGS="$TMPDIR_STATUS/launcher/launcher-args.StatusTest"
EOF
printf '%s\n' 'unknown' > "$TMPDIR_STATUS/data/last-world-save"
touch "$TMPDIR_STATUS/data/online-players" "$TMPDIR_STATUS/data/offline-players"
touch "$TMPDIR_STATUS/launcher/launcher-args.StatusTest"
printf 'first log line\nsecond "quoted" log line\nthird log line\n' > "$TMPDIR_STATUS/logs/server.log"

if ! VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" --for-webhook \
  > "$TMPDIR_STATUS/webhook-enabled.out"; then
  cat "$TMPDIR_STATUS/crash.log" >&2
  echo "FAIL: status webhook output failed with BepInEx enabled" >&2
  exit 1
fi
if ! grep -Fq 'R2Modman code' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq '01a1eaf3-9be3-9083-b9b4-26768368368e' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq '"title":"DisplayWorld","color":15158332' "$TMPDIR_STATUS/webhook-enabled.out" ||
   grep -Fq '"name":"Server name"' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq '203.0.113.1:2456' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq 'test-password' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq '"inline":false' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq '"title":"Last Logs"' "$TMPDIR_STATUS/webhook-enabled.out" ||
   ! grep -Fq 'second \"quoted\" log line' "$TMPDIR_STATUS/webhook-enabled.out"; then
  echo "FAIL: enabled BepInEx status did not include the R2Modman code" >&2
  exit 1
fi

sed -i 's/^SENDSERVERCONNECTIONINFO=1$/SENDSERVERCONNECTIONINFO=0/; s/^SENDLASTLOGS=2$/SENDLASTLOGS=0/' "$TMPDIR_STATUS/.env.StatusTest"
if ! VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" --for-webhook \
  > "$TMPDIR_STATUS/webhook-minimal.out"; then
  echo "FAIL: status webhook output failed with optional details disabled" >&2
  exit 1
fi
if ! grep -Fq '"title":"DisplayWorld","color":15158332' "$TMPDIR_STATUS/webhook-minimal.out" ||
   grep -Fq '"name":"Server name"' "$TMPDIR_STATUS/webhook-minimal.out" ||
   grep -Fq '"name":"IP"' "$TMPDIR_STATUS/webhook-minimal.out" ||
   grep -Fq '"title":"Last Logs"' "$TMPDIR_STATUS/webhook-minimal.out"; then
  echo "FAIL: optional details were not gated or server identity was missing" >&2
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

printf 'VALSERVERLASTOPEN="11/25/2026 16:21:00"\nVALSERVERLASTSHUTDOWN="11/25/2026 16:20:00"\n' >> "$TMPDIR_STATUS/.env.StatusTest"
if ! VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" --for-webhook \
    > "$TMPDIR_STATUS/webhook-online.out" ||
   ! grep -Fq '"title":"DisplayWorld","color":3066993' "$TMPDIR_STATUS/webhook-online.out" ||
   ! VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" > "$TMPDIR_STATUS/status-online.out" ||
   ! grep -Fq 'SERVER ONLINE !' "$TMPDIR_STATUS/status-online.out"; then
  echo 'FAIL: status did not use opening and shutdown dates for Discord and HTTP text' >&2
  exit 1
fi

sed -i 's/^VALSERVERLASTOPEN=.*/VALSERVERLASTOPEN="12\/31\/1999 23:58:00"/; s/^VALSERVERLASTSHUTDOWN=.*/VALSERVERLASTSHUTDOWN="12\/31\/1999 23:59:00"/' "$TMPDIR_STATUS/.env.StatusTest"
export MOCK_SERVICE_STATE=active MOCK_SERVICE_STARTED='2000-01-01 00:00:00'
if ! VSS_LANG=fr VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" --for-webhook \
    > "$TMPDIR_STATUS/webhook-starting.out" ||
   ! grep -Fq '"title":"DisplayWorld","color":16776960' "$TMPDIR_STATUS/webhook-starting.out" ||
   ! grep -Fq '"value":"DÉMARRAGE"' "$TMPDIR_STATUS/webhook-starting.out"; then
  echo 'FAIL: starting webhook did not show the localized yellow status' >&2
  exit 1
fi
if VSS_SERVER_NAME=StatusTest "$TMPDIR_STATUS/status/server-status" > "$TMPDIR_STATUS/status-starting.out" ||
   ! grep -Fq 'SERVER STARTING !' "$TMPDIR_STATUS/status-starting.out"; then
  echo 'FAIL: starting text status was not displayed' >&2
  exit 1
fi

echo "R2Modman status display OK"
