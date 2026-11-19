#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

source "$ROOT/setup" >/dev/null

CWD="$TEST_DIR/vss"
SYSTEMD_DIR="$TEST_DIR/systemd"
SERVICE='valheim-server.ServiceTest.service'
mkdir -p "$CWD/systemd" "$SYSTEMD_DIR"
printf 'generated unit\n' > "$CWD/systemd/$SERVICE"
printf 'installed unit\n' > "$SYSTEMD_DIR/$SERVICE"

SERVICE_ACTIVE=1
SERVICE_ENABLED=1
FAIL_STOP=1
systemctl() {
  case "$1" in
    is-active) [[ "$SERVICE_ACTIVE" -eq 1 ]] ;;
    is-enabled) [[ "$SERVICE_ENABLED" -eq 1 ]] ;;
    stop)
      [[ "$FAIL_STOP" -eq 0 ]] || return 1
      SERVICE_ACTIVE=0
      ;;
    disable) SERVICE_ENABLED=0 ;;
    reset-failed|daemon-reload) return 0 ;;
    *) return 1 ;;
  esac
}
sudo() {
  case "$1" in
    systemctl)
      shift
      systemctl "$@"
      ;;
    rm)
      shift
      command rm "$@"
      ;;
    *) return 1 ;;
  esac
}

if uninstall_service "$SERVICE" "$SYSTEMD_DIR"; then
  echo "FAIL: service removal ignored a failed systemctl stop" >&2
  exit 1
fi
if [[ ! -e "$SYSTEMD_DIR/$SERVICE" || ! -e "$CWD/systemd/$SERVICE" ]]; then
  echo "FAIL: service removal deleted unit files after a stop failure" >&2
  exit 1
fi

FAIL_STOP=0
if ! uninstall_service "$SERVICE" "$SYSTEMD_DIR"; then
  echo "FAIL: service removal failed after systemctl operations succeeded" >&2
  exit 1
fi
if [[ -e "$SYSTEMD_DIR/$SERVICE" || -e "$CWD/systemd/$SERVICE" ||
      "$SERVICE_ACTIVE" -ne 0 || "$SERVICE_ENABLED" -ne 0 ]]; then
  echo "FAIL: service removal did not stop, disable, and remove both unit files" >&2
  exit 1
fi

echo "setup service removal OK"
