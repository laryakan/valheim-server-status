#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_MIGRATION="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_MIGRATION"' EXIT

MIGRATION_ROOT="$TMPDIR_MIGRATION/vss"
MOCK_BIN="$TMPDIR_MIGRATION/bin"
SYSTEMD_ROOT="$TMPDIR_MIGRATION/systemd"
LOGROTATE_ROOT="$TMPDIR_MIGRATION/logrotate"
MOCK_CRONTAB="$TMPDIR_MIGRATION/crontab"
mkdir -p "$MIGRATION_ROOT"/{data,launcher,examples,lib,systemd,fake-server,discord} \
  "$MOCK_BIN" "$SYSTEMD_ROOT" "$LOGROTATE_ROOT"
cp "$ROOT/setup" "$ROOT/migrate-v2-to-v3" "$MIGRATION_ROOT/"
cp "$ROOT/.env.dist" "$MIGRATION_ROOT/"
cp "$ROOT/lib/config.sh" "$ROOT/lib/validation.sh" "$MIGRATION_ROOT/lib/"
cp "$ROOT"/examples/* "$MIGRATION_ROOT/examples/"
cp "$ROOT/examples/launcher-args" "$MIGRATION_ROOT/launcher/"

cat > "$MOCK_BIN/dig" <<'EOF'
#!/bin/sh
printf '203.0.113.1\n'
EOF
cat > "$MOCK_BIN/crontab" <<'EOF'
#!/bin/bash
case "${1:-}" in
  -l)
    [ -f "$MOCK_CRONTAB" ] || exit 1
    cat "$MOCK_CRONTAB"
    ;;
  -)
    cat > "$MOCK_CRONTAB"
    ;;
  *)
    exit 2
    ;;
esac
EOF
cat > "$MOCK_BIN/systemctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$MOCK_SYSTEMCTL_CALLS"
EOF
cat > "$MOCK_BIN/ufw" <<'EOF'
#!/bin/bash
if [ "$*" != status ]; then
  exit 2
fi
cat <<'STATUS'
Status: active

To                         Action      From
--                         ------      ----
2456:2458/tcp              ALLOW IN    Anywhere
2456:2458/udp              ALLOW IN    Anywhere
8181/tcp                   ALLOW IN    Anywhere
STATUS
EOF
cat > "$MOCK_BIN/ps" <<'EOF'
#!/bin/sh
case "$1" in
  -p) exit 1 ;;
  *) exit 0 ;;
esac
EOF
cat > "$MOCK_BIN/sudo" <<'EOF'
#!/bin/bash
case "${1:-}" in
  systemctl)
    shift
    exec "$MOCK_BIN/systemctl" "$@"
    ;;
  chown)
    exit 0
    ;;
  *)
    exec "$@"
    ;;
esac
EOF
chmod +x "$MOCK_BIN/"*

cat > "$MIGRATION_ROOT/.env" <<EOF
VSSDIR="$MIGRATION_ROOT"
VHSERVERWORLD='MigrationWorld'
VHSERVERDIR="$MIGRATION_ROOT/fake-server"
WEBHOOKUPDATE="$MIGRATION_ROOT/discord/update"
CRONTABWEBHOOKFREQ=5
VHSERVERPORT=2456
STATUSPORT=8181
CONNECTEDPLAYERSFILE="$MIGRATION_ROOT/data/online-players"
OFFLINEPLAYERSFILE="$MIGRATION_ROOT/data/offline-players"
STEAMIDMAPFILE="$MIGRATION_ROOT/data/steamid-player-map"
LASTWORLDSAVEFILE="$MIGRATION_ROOT/data/last-world-save"
EOF
printf '%s\n' '-saveinterval 1800' > "$MIGRATION_ROOT/launcher/launcher-args"
printf '%s\n' 'online state' > "$MIGRATION_ROOT/data/online-players"
printf '%s\n' 'offline state' > "$MIGRATION_ROOT/data/offline-players"
printf '%s\n' 'steam map' > "$MIGRATION_ROOT/data/steamid-player-map"
printf '%s\n' 'save timestamp' > "$MIGRATION_ROOT/data/last-world-save"
printf '%s\n' 'legacy systemd unit' > "$SYSTEMD_ROOT/valheim-server.service"
printf '%s\n' 'legacy pipe unit' > "$SYSTEMD_ROOT/vss.pipe.service"
printf '%s\n' 'legacy HTTP unit' > "$SYSTEMD_ROOT/vss.http.service"
printf '%s\n' 'legacy logrotate rule' > "$LOGROTATE_ROOT/valheim"
printf '%s\n' \
  "*/5 * * * * $MIGRATION_ROOT/discord/update" \
  '15 2 * * * /usr/local/bin/backup-world' > "$MOCK_CRONTAB"

export PATH="$MOCK_BIN:$PATH"
export MOCK_BIN MOCK_CRONTAB="$MOCK_CRONTAB" MOCK_SYSTEMCTL_CALLS="$TMPDIR_MIGRATION/systemctl.calls"
export VSS_MIGRATION_SYSTEMD_DIR="$SYSTEMD_ROOT"
export VSS_MIGRATION_LOGROTATE_DIR="$LOGROTATE_ROOT"

if ! printf 'MIGRATE\nSTART\n' | "$MIGRATION_ROOT/migrate-v2-to-v3" > "$TMPDIR_MIGRATION/output" 2>&1; then
  cat "$TMPDIR_MIGRATION/output"
  echo "FAIL: V2-to-V3 migration command failed" >&2
  exit 1
fi

if [ -e "$MIGRATION_ROOT/.env" ] || [ ! -f "$MIGRATION_ROOT/.env.MigrationWorld" ]; then
  echo "FAIL: legacy configuration was not migrated to a profile" >&2
  exit 1
fi
if [ -e "$MIGRATION_ROOT/launcher/launcher-args" ] ||
   [ ! -f "$MIGRATION_ROOT/launcher/launcher-args.MigrationWorld" ]; then
  echo "FAIL: launcher arguments were not migrated" >&2
  exit 1
fi
if ! grep -Fxq 'online state' "$MIGRATION_ROOT/data/online-players.MigrationWorld" ||
   ! grep -Fxq 'offline state' "$MIGRATION_ROOT/data/offline-players.MigrationWorld" ||
   ! grep -Fxq 'steam map' "$MIGRATION_ROOT/data/steamid-player-map.MigrationWorld" ||
   ! grep -Fxq 'save timestamp' "$MIGRATION_ROOT/data/last-world-save.MigrationWorld"; then
  echo "FAIL: VSS state did not survive the migration" >&2
  exit 1
fi

cron="$(cat "$MOCK_CRONTAB")"
if [[ "$cron" != *"VSS_SERVER_NAME=MigrationWorld $MIGRATION_ROOT/discord/update # vss-profile:MigrationWorld"* ]] ||
   [[ "$cron" == *"*/5 * * * * $MIGRATION_ROOT/discord/update"* ]] ||
   [[ "$cron" != *'/usr/local/bin/backup-world'* ]]; then
  echo "FAIL: cron migration did not replace only the V2 webhook job" >&2
  exit 1
fi
if [ ! -f "$LOGROTATE_ROOT/valheim-vss" ] || [ -e "$LOGROTATE_ROOT/valheim" ]; then
  echo "FAIL: logrotate was not migrated to the shared V3 rule" >&2
  exit 1
fi
for unit in \
  valheim-server.MigrationWorld.service \
  vss.pipe.MigrationWorld.service \
  vss.http.MigrationWorld.service; do
  if [ ! -L "$SYSTEMD_ROOT/$unit" ] || [ ! -f "$MIGRATION_ROOT/systemd/$unit" ]; then
    printf 'FAIL: V3 systemd unit was not installed: %s\n' "$unit" >&2
    exit 1
  fi
done
for old_unit in valheim-server.service vss.pipe.service vss.http.service; do
  if [ ! -f "$SYSTEMD_ROOT/$old_unit" ] ||
     ! grep -Fq "disable $old_unit" "$MOCK_SYSTEMCTL_CALLS"; then
    printf 'FAIL: legacy unit was not retained and disabled: %s\n' "$old_unit" >&2
    exit 1
  fi
done
if ! grep -Fq 'start valheim-server.MigrationWorld.service' "$MOCK_SYSTEMCTL_CALLS" ||
   ! grep -Fq 'start vss.pipe.MigrationWorld.service' "$MOCK_SYSTEMCTL_CALLS" ||
   ! grep -Fq 'start vss.http.MigrationWorld.service' "$MOCK_SYSTEMCTL_CALLS"; then
  echo "FAIL: V3 services did not start after confirmation" >&2
  exit 1
fi
if ! grep -Fq 'UFW ALLOW rules found for MigrationWorld' "$TMPDIR_MIGRATION/output"; then
  echo "FAIL: migration did not check the profile's UFW rules" >&2
  exit 1
fi

backup_dir="$(find "$MIGRATION_ROOT/migration-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
if [ -z "$backup_dir" ] ||
   [ "$(stat -c '%a' "$backup_dir")" != '700' ] ||
   ! grep -Fq "$MIGRATION_ROOT/discord/update" "$backup_dir/crontab" ||
   ! grep -Fxq 'online state' "$backup_dir/data/online-players" ||
   ! grep -Fxq 'legacy logrotate rule' "$backup_dir/logrotate/valheim"; then
  echo "FAIL: migration backup is missing protected legacy files" >&2
  exit 1
fi

echo "V2-to-V3 migration workflow OK"
