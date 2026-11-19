#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_DISCORD="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_DISCORD"' EXIT

mkdir -p "$TMPDIR_DISCORD"/{discord,status,lib,data,launcher,logs,bin}
cp "$ROOT/discord/update" "$TMPDIR_DISCORD/discord/update"
cp "$ROOT/lib/config.sh" "$TMPDIR_DISCORD/lib/config.sh"
cp "$ROOT/i18n.sh" "$TMPDIR_DISCORD/i18n.sh"
cat > "$TMPDIR_DISCORD/.env" <<EOF
VSS_COMMON_CONFIG_VERSION=3
VSSDIR="$TMPDIR_DISCORD"
WEBHOOKURL='https://discord.com/api/webhooks/123456789/fake-token'
WEBHOOKID=123456789
WEBHOOKTOKEN=fake-token
EOF
cat > "$TMPDIR_DISCORD/.env.SingleMessage" <<EOF
VHSERVERWORLD=SingleMessage
VHSERVERNAME='Single Message World'
VHSERVERPORT=2456
STATUSMESSAGEID=''
LASTLOGMESSAGEID=222
SERVERCONNECTIONINFOMESSAGEID=333
SENDSERVERCONNECTIONINFO=1
SENDLASTLOGS=2
VALHEIMSERVERLOGPATH="$TMPDIR_DISCORD/logs/*.log"
EOF
printf 'log line\n' > "$TMPDIR_DISCORD/logs/server.log"

cat > "$TMPDIR_DISCORD/status/server-status" <<'EOF'
#!/bin/bash
printf 'status\n' >> "$CALLS"
printf '{"embeds":[{"title":"status"},{"title":"logs"}]}'
EOF
cat > "$TMPDIR_DISCORD/discord/webhook.json-sender" <<'EOF'
#!/bin/bash
printf 'sender:%s\n' "$*" >> "$CALLS"
cat > "$PAYLOAD"
EOF
cat > "$TMPDIR_DISCORD/discord/connection-info" <<'EOF'
#!/bin/bash
printf 'connection-info\n' >> "$CALLS"
EOF
cat > "$TMPDIR_DISCORD/discord/last-logs" <<'EOF'
#!/bin/bash
printf 'last-logs\n' >> "$CALLS"
EOF
chmod +x "$TMPDIR_DISCORD"/{status/server-status,discord/webhook.json-sender,discord/connection-info,discord/last-logs}
export CALLS="$TMPDIR_DISCORD/calls" PAYLOAD="$TMPDIR_DISCORD/payload"

if ! VSS_SERVER_NAME=SingleMessage "$TMPDIR_DISCORD/discord/update"; then
  echo "FAIL: Discord update failed" >&2
  exit 1
fi
if [ "$(grep -c '^sender:' "$CALLS")" -ne 1 ] ||
   ! grep -Fxq 'sender:--status' "$CALLS" ||
   ! grep -Fxq 'status' "$CALLS" ||
   grep -Eq 'connection-info|last-logs' "$CALLS" ||
   ! grep -Fq '"title":"logs"' "$PAYLOAD"; then
  echo "FAIL: the update did not send one combined status-and-logs payload" >&2
  exit 1
fi

cp "$ROOT/discord/webhook.json-sender" "$TMPDIR_DISCORD/discord/webhook.json-sender"
cat > "$TMPDIR_DISCORD/bin/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$CURL_CALLS"
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-o' ]; then
    : > "$2"
    break
  fi
  shift
done
printf '200'
EOF
chmod +x "$TMPDIR_DISCORD/bin/curl"
export CURL_CALLS="$TMPDIR_DISCORD/curl-calls"
if ! printf '{}' | PATH="$TMPDIR_DISCORD/bin:$PATH" VSS_SERVER_NAME=SingleMessage \
  "$TMPDIR_DISCORD/discord/webhook.json-sender" --status; then
  echo "FAIL: legacy message-ID fallback failed" >&2
  exit 1
fi
if ! grep -Fq 'PATCH' "$CURL_CALLS" ||
   ! grep -Fq '/messages/222' "$CURL_CALLS" ||
   grep -Fq '/messages/333' "$CURL_CALLS"; then
  echo "FAIL: status update did not reuse one legacy message ID" >&2
  exit 1
fi

echo "single Discord message update OK"
