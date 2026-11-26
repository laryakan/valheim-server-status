#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_BEPINEX="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BEPINEX"' EXIT

source "$ROOT/lib/bepinex.sh"

VSSDIR="$TMPDIR_BEPINEX"
VSS_SERVER_NAME='RuntimeTest'
VSSBEPINEXDIR="$TMPDIR_BEPINEX/bepinex/profiles/RuntimeTest"
mkdir -p "$VSSBEPINEXDIR/BepInEx/core"
touch "$VSSBEPINEXDIR/BepInEx/core/BepInEx.Preloader.dll"
touch "$VSSBEPINEXDIR/libdoorstop.so"

VSSBEPINEXENABLED=1
LD_LIBRARY_PATH="$TMPDIR_BEPINEX/bepinex/profiles/Other/doorstop_libs:/usr/lib/valheim:$TMPDIR_BEPINEX/bepinex/current/doorstop_libs"
LD_PRELOAD='/old/bepinex/doorstop_libs/libdoorstop.so:/usr/lib/example.so'
DOORSTOP_INVOKE_DLL_PATH='/old/profile/BepInEx/core/BepInEx.Preloader.dll'
if ! vss_bepinex_configure_runtime; then
  echo "FAIL: enabled BepInEx runtime was rejected" >&2
  exit 1
fi
if [[ "$DOORSTOP_TARGET_ASSEMBLY" != "$VSSBEPINEXDIR/BepInEx/core/BepInEx.Preloader.dll" ]]; then
  echo "FAIL: Doorstop target did not use the profile-specific preloader path" >&2
  exit 1
fi
if [[ "$LD_LIBRARY_PATH" != "$VSSBEPINEXDIR:/usr/lib/valheim" ]]; then
  echo "FAIL: Doorstop library search path retained stale profiles or missed the active profile" >&2
  exit 1
fi
if [[ "$LD_PRELOAD" != "$VSSBEPINEXDIR/libdoorstop.so:/usr/lib/example.so" ]]; then
  echo "FAIL: Doorstop preload was not profile-specific or duplicated" >&2
  exit 1
fi
if [[ -n "${DOORSTOP_INVOKE_DLL_PATH:-}" ]]; then
  echo "FAIL: inherited Doorstop invocation path was not cleared" >&2
  exit 1
fi

VSSBEPINEXENABLED=0
DOORSTOP_ENABLED=1
DOORSTOP_TARGET_ASSEMBLY='/old/profile/BepInEx/core/BepInEx.Preloader.dll'
DOORSTOP_INVOKE_DLL_PATH='/old/profile/BepInEx/core/BepInEx.Preloader.dll'
LD_PRELOAD="$VSSDIR/bepinex/current/libdoorstop.so:/usr/lib/example.so"
if ! vss_bepinex_configure_runtime; then
  echo "FAIL: disabled BepInEx runtime cleanup failed" >&2
  exit 1
fi
if [[ -n "${DOORSTOP_ENABLED:-}${DOORSTOP_TARGET_ASSEMBLY:-}${DOORSTOP_INVOKE_DLL_PATH:-}" ]]; then
  echo "FAIL: Doorstop environment remained enabled for a disabled profile" >&2
  exit 1
fi
if [[ "$LD_PRELOAD" != '/usr/lib/example.so' ]]; then
  echo "FAIL: disabled profile retained Doorstop in LD_PRELOAD" >&2
  exit 1
fi
if [[ "$LD_LIBRARY_PATH" != '/usr/lib/valheim' ]]; then
  echo "FAIL: disabled profile retained a BepInEx library search path" >&2
  exit 1
fi

unset LD_PRELOAD

LAUNCH_ROOT="$TMPDIR_BEPINEX/vss"
GAME_DIR="$TMPDIR_BEPINEX/game"
mkdir -p "$LAUNCH_ROOT/launcher" "$LAUNCH_ROOT/lib" "$LAUNCH_ROOT/bin" "$LAUNCH_ROOT/launcher" "$GAME_DIR"
cp "$ROOT/launcher/start_server_custom.sh" "$LAUNCH_ROOT/launcher/"
cp "$ROOT/lib/config.sh" "$ROOT/lib/bepinex.sh" "$LAUNCH_ROOT/lib/"
cat > "$LAUNCH_ROOT/.env" <<EOF
VSS_COMMON_CONFIG_VERSION=3
VSSDIR="$LAUNCH_ROOT"
VHSERVERDIR="$GAME_DIR"
VHSERVERSAVEDIR="$LAUNCH_ROOT/saved"
VSSLOGFILTER="$LAUNCH_ROOT/bin/log-filter"
VSSERRFILTER="$LAUNCH_ROOT/bin/err-filter"
EOF
cat > "$LAUNCH_ROOT/.env.Vanilla" <<'EOF'
VHSERVERWORLD='Vanilla'
VHSERVERNAME='Vanilla'
VHSERVERPORT=2456
VHSERVERPASSWD='test-password'
VHSERVERCROSSPLAY=0
VHSERVERLAUNCHERARGS="$VSSDIR/launcher/launcher-args.Vanilla"
VSSBEPINEXENABLED=0
VSSBEPINEXDIR="$VSSDIR/bepinex/current/"
VSSBEPINEXLOGOUTPUT="$VSSBEPINEXDIR/BepInEx/LogOutput.log"
EOF
touch "$LAUNCH_ROOT/launcher/launcher-args.Vanilla"
for filter in log-filter err-filter; do
  printf '#!/bin/bash\ncat >/dev/null\n' > "$LAUNCH_ROOT/bin/$filter"
  chmod +x "$LAUNCH_ROOT/bin/$filter"
done
cat > "$GAME_DIR/valheim_server.x86_64" <<'EOF'
#!/bin/bash
{
  printf 'VSS_SERVER_NAME=%s\n' "${VSS_SERVER_NAME:-}"
  printf 'DOORSTOP_ENABLED=%s\n' "${DOORSTOP_ENABLED:-}"
  printf 'DOORSTOP_TARGET_ASSEMBLY=%s\n' "${DOORSTOP_TARGET_ASSEMBLY:-}"
  printf 'DOORSTOP_INVOKE_DLL_PATH=%s\n' "${DOORSTOP_INVOKE_DLL_PATH:-}"
  printf 'DOORSTOP_MANAGED_FOLDER_DIR=%s\n' "${DOORSTOP_MANAGED_FOLDER_DIR:-}"
  printf 'LD_PRELOAD=%s\n' "${LD_PRELOAD:-}"
  printf 'LD_LIBRARY_PATH=%s\n' "${LD_LIBRARY_PATH:-}"
} > "$VSS_CAPTURE_FILE"
EOF
chmod +x "$GAME_DIR/valheim_server.x86_64"
export VSS_CAPTURE_FILE="$TMPDIR_BEPINEX/vanilla-env"
if ! env \
  VSS_SERVER_NAME=Vanilla \
  DOORSTOP_ENABLED=1 \
  DOORSTOP_TARGET_ASSEMBLY='/old/shared/BepInEx/core/BepInEx.Preloader.dll' \
  DOORSTOP_INVOKE_DLL_PATH='/old/shared/BepInEx/core/BepInEx.Preloader.dll' \
  DOORSTOP_MANAGED_FOLDER_DIR='/old/shared/Managed' \
  LD_PRELOAD="$TMPDIR_BEPINEX/old/doorstop_libs/libdoorstop.so" \
  LD_LIBRARY_PATH="$LAUNCH_ROOT/bepinex/profiles/Other/doorstop_libs:$LAUNCH_ROOT/bepinex/current/doorstop_libs:/usr/lib/example" \
  "$LAUNCH_ROOT/launcher/start_server_custom.sh" \
  > "$TMPDIR_BEPINEX/vanilla.out" 2> "$TMPDIR_BEPINEX/vanilla.err"; then
  echo "FAIL: vanilla profile launcher failed" >&2
  exit 1
fi
for variable in DOORSTOP_ENABLED DOORSTOP_TARGET_ASSEMBLY DOORSTOP_INVOKE_DLL_PATH DOORSTOP_MANAGED_FOLDER_DIR LD_PRELOAD; do
  if ! grep -Fxq "$variable=" "$VSS_CAPTURE_FILE"; then
    printf 'FAIL: vanilla Valheim process inherited %s\n' "$variable" >&2
    exit 1
  fi
done
if grep -Fq 'doorstop_libs' "$VSS_CAPTURE_FILE"; then
  echo "FAIL: vanilla Valheim process inherited a BepInEx library search path" >&2
  exit 1
fi

create_enabled_profile() {
  local profile="$1"
  local profile_root="$LAUNCH_ROOT/bepinex/profiles/$profile"

  cat > "$LAUNCH_ROOT/.env.$profile" <<EOF
VHSERVERWORLD='$profile'
VHSERVERNAME='$profile'
VHSERVERPORT=2456
VHSERVERPASSWD='test-password'
VHSERVERCROSSPLAY=0
VHSERVERLAUNCHERARGS="\$VSSDIR/launcher/launcher-args.$profile"
VSSBEPINEXENABLED=1
VSSBEPINEXDIR="\$VSSDIR/bepinex/profiles/$profile"
VSSBEPINEXLOGOUTPUT="\$VSSBEPINEXDIR/BepInEx/LogOutput.log"
EOF
  mkdir -p "$profile_root/BepInEx/core"
  touch "$profile_root/BepInEx/core/BepInEx.Preloader.dll"
  touch "$profile_root/libdoorstop.so"
  touch "$LAUNCH_ROOT/launcher/launcher-args.$profile"
}

create_enabled_profile ModAlpha
create_enabled_profile ModBeta

launch_profile() {
  local profile="$1"
  local capture_file="$TMPDIR_BEPINEX/concurrent-$profile-env"
  local inherited_profile="$LAUNCH_ROOT/bepinex/profiles/ModAlpha"

  env \
    VSS_SERVER_NAME="$profile" \
    VSS_CAPTURE_FILE="$capture_file" \
    DOORSTOP_ENABLED=1 \
    DOORSTOP_TARGET_ASSEMBLY="$inherited_profile/BepInEx/core/BepInEx.Preloader.dll" \
    DOORSTOP_INVOKE_DLL_PATH="$inherited_profile/BepInEx/core/BepInEx.Preloader.dll" \
    DOORSTOP_MANAGED_FOLDER_DIR="$inherited_profile/Managed" \
    LD_PRELOAD="$inherited_profile/doorstop_libs/libdoorstop.so:/usr/lib/example.so" \
    LD_LIBRARY_PATH="$inherited_profile/doorstop_libs:$LAUNCH_ROOT/bepinex/profiles/ModBeta/doorstop_libs:/usr/lib/example" \
    "$LAUNCH_ROOT/launcher/start_server_custom.sh" \
    > "$TMPDIR_BEPINEX/concurrent-$profile.out" \
    2> "$TMPDIR_BEPINEX/concurrent-$profile.err"
}

launch_profile ModAlpha &
MOD_ALPHA_PID=$!
launch_profile ModBeta &
MOD_BETA_PID=$!
launch_profile Vanilla &
VANILLA_PID=$!

for launch_pid in "$MOD_ALPHA_PID" "$MOD_BETA_PID" "$VANILLA_PID"; do
  if ! wait "$launch_pid"; then
    echo "FAIL: a concurrent profile launcher exited unsuccessfully" >&2
    exit 1
  fi
done

for profile in ModAlpha ModBeta; do
  capture_file="$TMPDIR_BEPINEX/concurrent-$profile-env"
  profile_root="$LAUNCH_ROOT/bepinex/profiles/$profile"
  if ! grep -Fxq "VSS_SERVER_NAME=$profile" "$capture_file" ||
     ! grep -Fxq 'DOORSTOP_ENABLED=1' "$capture_file" ||
     ! grep -Fxq "DOORSTOP_TARGET_ASSEMBLY=$profile_root/BepInEx/core/BepInEx.Preloader.dll" "$capture_file" ||
     ! grep -Fxq "LD_PRELOAD=$profile_root/libdoorstop.so:/usr/lib/example.so" "$capture_file" ||
     ! grep -Fxq "LD_LIBRARY_PATH=$profile_root:./linux64:/usr/lib/example" "$capture_file"; then
    printf 'FAIL: profile %s received another profile’s BepInEx environment\n' "$profile" >&2
    exit 1
  fi
done

VANILLA_CAPTURE="$TMPDIR_BEPINEX/concurrent-Vanilla-env"
if ! grep -Fxq 'VSS_SERVER_NAME=Vanilla' "$VANILLA_CAPTURE" ||
   ! grep -Fxq 'DOORSTOP_ENABLED=' "$VANILLA_CAPTURE" ||
   ! grep -Fxq 'DOORSTOP_TARGET_ASSEMBLY=' "$VANILLA_CAPTURE" ||
   ! grep -Fxq 'LD_PRELOAD=/usr/lib/example.so' "$VANILLA_CAPTURE" ||
   ! grep -Fxq 'LD_LIBRARY_PATH=./linux64:/usr/lib/example' "$VANILLA_CAPTURE" ||
   grep -Fq 'libdoorstop.so' "$VANILLA_CAPTURE"; then
  echo "FAIL: vanilla profile inherited BepInEx settings from a modded profile" >&2
  exit 1
fi

echo "BepInEx runtime isolation OK"
