#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_PORTS="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PORTS"' EXIT

source "$ROOT/setup" >/dev/null
CWD="$TMPDIR_PORTS"
mkdir -p "$CWD/lib" "$CWD/bin"
cp "$ROOT/lib/config.sh" "$CWD/lib/config.sh"
printf '#!/bin/sh\nexit 0\n' > "$CWD/bin/ufw"
chmod +x "$CWD/bin/ufw"
PATH="$CWD/bin:$PATH"

cat > "$CWD/.env.Alpha" <<'EOF'
VHSERVERWORLD='Alpha'
VHSERVERPORT=2456
STATUSPORT=8181
EOF
cat > "$CWD/.env.Beta" <<'EOF'
VHSERVERWORLD='Beta'
VHSERVERPORT=2460
STATUSPORT=8182
EOF

if validate_server_profile_ports Beta 2458 8182 >/dev/null 2>&1; then
  echo "FAIL: overlapping Valheim port ranges were accepted" >&2
  exit 1
fi
if validate_server_profile_ports Beta 2460 8181 >/dev/null 2>&1; then
  echo "FAIL: duplicate HTTP ports were accepted" >&2
  exit 1
fi
if validate_server_profile_ports Beta 2460 2457 >/dev/null 2>&1; then
  echo "FAIL: HTTP port overlapping another server's game range was accepted" >&2
  exit 1
fi
if validate_server_profile_ports Beta 8181 9000 >/dev/null 2>&1; then
  echo "FAIL: game port range overlapping another server's HTTP port was accepted" >&2
  exit 1
fi
if ! validate_server_profile_ports Beta 2460 8182; then
  echo "FAIL: non-overlapping ports were rejected" >&2
  exit 1
fi
if ! validate_server_profile_ports Beta 2460 invalid 0; then
  echo "FAIL: an unused HTTP port was validated" >&2
  exit 1
fi
if validate_server_profile_ports Beta 2460 invalid 1 >/dev/null 2>&1; then
  echo "FAIL: an active HTTP port accepted a non-numeric value" >&2
  exit 1
fi

VSS_SERVER_NAME=Beta
VSS_ENV_FILE="$CWD/.env.Beta"
VHSERVERPORT=2460
STATUSPORT=8182
if replace_env_value VHSERVERPORT 2458 >/dev/null 2>&1; then
  echo "FAIL: setup saved a port range that overlaps another profile" >&2
  exit 1
fi
if ! grep -Fxq 'VHSERVERPORT=2460' "$VSS_ENV_FILE"; then
  echo "FAIL: rejected port change modified the profile" >&2
  exit 1
fi

sudo() {
  [ "$1" = ufw ] && [ "$2" = status ] || return 2
  printf '%s\n' "$MOCK_UFW_STATUS"
}
VSS_SERVER_NAME=Beta
VHSERVERPORT=2460
STATUSPORT=8182
MOCK_UFW_STATUS=$'Status: active\n\nTo                         Action      From\n--                         ------      ----\n2460:2462/tcp              ALLOW IN    Anywhere\n2460:2462/udp              ALLOW IN    Anywhere\n8182/tcp                   ALLOW IN    Anywhere\n'
if ! check_ufw_profile_rules > "$TMPDIR_PORTS/ufw.out" 2>&1 ||
   ! grep -Fq 'UFW ALLOW rules found for Beta' "$TMPDIR_PORTS/ufw.out"; then
  echo "FAIL: complete UFW range rules were not recognized" >&2
  exit 1
fi

MOCK_UFW_STATUS=$'Status: active\n\nTo                         Action      From\n--                         ------      ----\n2460:2462/udp              ALLOW IN    Anywhere\n8182/tcp                   ALLOW IN    Anywhere\n'
if check_ufw_profile_rules > "$TMPDIR_PORTS/ufw-missing.out" 2>&1; then
  echo "FAIL: missing game TCP rules were not reported" >&2
  exit 1
fi
if ! grep -Fq '2460/tcp' "$TMPDIR_PORTS/ufw-missing.out"; then
  echo "FAIL: missing UFW ports were not identified" >&2
  exit 1
fi

MOCK_UFW_STATUS=$'Status: inactive\n'
if check_ufw_profile_rules > "$TMPDIR_PORTS/ufw-inactive.out" 2>&1; then
  echo "FAIL: inactive UFW was reported as verified" >&2
  exit 1
fi
if ! grep -Fq 'UFW is inactive' "$TMPDIR_PORTS/ufw-inactive.out"; then
  echo "FAIL: inactive UFW warning was not reported" >&2
  exit 1
fi

VHSERVERPORT=2460
STATUSPORT=invalid
MOCK_UFW_STATUS=$'Status: active\n\nTo                         Action      From\n--                         ------      ----\n2460:2462/tcp              ALLOW IN    Anywhere\n2460:2462/udp              ALLOW IN    Anywhere\n'
if ! check_ufw_profile_rules 0 > "$TMPDIR_PORTS/ufw-no-http.out" 2>&1 ||
   ! grep -Fq 'HTTP status is not installed' "$TMPDIR_PORTS/ufw-no-http.out"; then
  echo "FAIL: disabled HTTP port prevented the UFW game-port check" >&2
  exit 1
fi

echo "cross-profile port validation OK"
