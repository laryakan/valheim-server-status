#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_BIN="$TEST_DIR/bin"
mkdir -p "$MOCK_BIN"
export MOCK_ROOT_CRON="$TEST_DIR/root-crontab"
cat > "$MOCK_BIN/sudo" <<'EOF'
#!/bin/bash
if [ "$1" != crontab ]; then
  exit 2
fi
case "${2:-}" in
  -l)
    [ -f "$MOCK_ROOT_CRON" ] || {
      echo "no crontab for root" >&2
      exit 1
    }
    cat "$MOCK_ROOT_CRON"
    ;;
  -)
    cat > "$MOCK_ROOT_CRON"
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$MOCK_BIN/sudo"
export PATH="$MOCK_BIN:$PATH"

source "$ROOT/setup" >/dev/null
CWD="$TEST_DIR/vss"
mkdir -p "$CWD"
printf '%s\n' '15 2 * * * /usr/local/bin/backup-world' > "$MOCK_ROOT_CRON"

if ! setup_main --schedule-maintenance; then
  echo "FAIL: global maintenance schedule command failed" >&2
  exit 1
fi
if ! setup_main --schedule-maintenance; then
  echo "FAIL: repeating the schedule command was not idempotent" >&2
  exit 1
fi
if [ "$(grep -Fxc "0 5 * * * $CWD/vss.maintenance # vss-maintenance" "$MOCK_ROOT_CRON")" -ne 1 ] ||
   ! grep -Fxq '15 2 * * * /usr/local/bin/backup-world' "$MOCK_ROOT_CRON"; then
  echo "FAIL: schedule was not unique or unrelated root cron entries changed" >&2
  exit 1
fi
if ! setup_main --schedule-maintenance --no-upgrade ||
   ! setup_main --schedule-maintenance --no-upgrade ||
   [ "$(grep -Fxc "0 5 * * * $CWD/vss.maintenance --no-upgrade # vss-maintenance" "$MOCK_ROOT_CRON")" -ne 1 ] ||
   [ "$(grep -Fc '# vss-maintenance' "$MOCK_ROOT_CRON")" -ne 1 ] ||
   ! grep -Fxq '15 2 * * * /usr/local/bin/backup-world' "$MOCK_ROOT_CRON"; then
  echo 'FAIL: restart-only schedule did not replace the previous entry idempotently' >&2
  exit 1
fi
if setup_main --schedule-maintenance --no-upgrade extra ||
   setup_main --schedule-maintenance invalid ||
   ! grep -Fxq "0 5 * * * $CWD/vss.maintenance --no-upgrade # vss-maintenance" "$MOCK_ROOT_CRON"; then
  echo 'FAIL: invalid scheduling arguments changed the cron entry' >&2
  exit 1
fi
maintenance_check_output="$(check_maintenance_cron)"
if [[ "$maintenance_check_output" != *"Global maintenance schedule is present in root's crontab."* ]]; then
  echo "FAIL: maintenance schedule check did not detect the configured root cron entry" >&2
  exit 1
fi

if ! setup_main --remove-maintenance-schedule; then
  echo "FAIL: global maintenance schedule removal failed" >&2
  exit 1
fi
if grep -Fq 'vss.maintenance' "$MOCK_ROOT_CRON" ||
   ! grep -Fxq '15 2 * * * /usr/local/bin/backup-world' "$MOCK_ROOT_CRON"; then
  echo "FAIL: removal changed unrelated root cron entries or kept maintenance" >&2
  exit 1
fi
maintenance_check_output="$(check_maintenance_cron)"
if [[ "$maintenance_check_output" != *"No VSS maintenance schedule found in root's crontab."* ]]; then
  echo "FAIL: maintenance schedule check reported a removed entry as present" >&2
  exit 1
fi

rm "$MOCK_ROOT_CRON"
maintenance_check_output="$(check_maintenance_cron)"
if [[ "$maintenance_check_output" != *"Root has no crontab; no VSS maintenance schedule is configured."* ]]; then
  echo "FAIL: maintenance schedule check did not handle an empty root crontab" >&2
  exit 1
fi

echo "global maintenance cron scheduling OK"
