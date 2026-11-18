#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_UPGRADE="$(mktemp -d)"
HTTP_PID=''
cleanup() {
    if [[ -n "$HTTP_PID" ]]; then
        kill "$HTTP_PID" 2>/dev/null || true
        wait "$HTTP_PID" 2>/dev/null || true
    fi
    rm -rf "$TMPDIR_UPGRADE"
}
trap cleanup EXIT

for command_name in wget unzip ncat base64 find; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'FAIL: test_bepinex_upgrade.sh requires %s\n' "$command_name" >&2
        exit 1
    fi
done

HTTP_HANDLER="$TMPDIR_UPGRADE/http-handler.sh"
cat > "$HTTP_HANDLER" <<'HANDLER'
#!/bin/bash
IFS= read -r request || exit 0
request_path="${request#* }"
request_path="${request_path%% *}"
while IFS= read -r header; do
    [[ "$header" == $'\r' || -z "$header" ]] && break
done

case "$request_path" in
    /release-*.json|/BepInEx_linux_x64_*.zip)
        fixture_file="$FIXTURE_DIR${request_path}"
        ;;
    *)
        fixture_file=''
        ;;
esac

if [[ -z "$fixture_file" || ! -f "$fixture_file" ]]; then
    printf 'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
    exit 0
fi

content_length="$(wc -c < "$fixture_file")"
printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\nConnection: close\r\nContent-Type: application/octet-stream\r\n\r\n' "$content_length"
cat "$fixture_file"
HANDLER
chmod +x "$HTTP_HANDLER"
FIXTURE_DIR="$TMPDIR_UPGRADE"
export FIXTURE_DIR

HTTP_PORT=$((20000 + $$ % 20000))
HTTP_READY=0
for ((attempt = 0; attempt < 20; attempt++)); do
    ncat -4 -l -k -p "$HTTP_PORT" --exec "$HTTP_HANDLER" > "$TMPDIR_UPGRADE/http-server.log" 2>&1 &
    HTTP_PID=$!
    for ((probe = 0; probe < 20; probe++)); do
        if ! kill -0 "$HTTP_PID" 2>/dev/null; then
            break
        fi
        if ncat -4 -z -w 1 127.0.0.1 "$HTTP_PORT" >/dev/null 2>&1; then
            HTTP_READY=1
            break
        fi
        sleep 0.1
    done
    [[ "$HTTP_READY" -eq 1 ]] && break
    kill "$HTTP_PID" 2>/dev/null || true
    wait "$HTTP_PID" 2>/dev/null || true
    HTTP_PID=''
    HTTP_PORT=$((HTTP_PORT + 1))
done
if [[ "$HTTP_READY" -ne 1 ]]; then
    echo "FAIL: could not start local fixture HTTP server with ncat" >&2
    exit 1
fi
FIXTURE_BASE_URL="http://127.0.0.1:$HTTP_PORT"

TEST_ROOT="$TMPDIR_UPGRADE/vss"
BEPINEX_DIR="$TEST_ROOT/bepinex"
OLD_VERSION="$BEPINEX_DIR/BepInEx_linux_x64_5.4.23.5"
mkdir -p "$OLD_VERSION/BepInEx/config" "$OLD_VERSION/BepInEx/core" "$OLD_VERSION/doorstop_libs"
printf 'old package config\n' > "$OLD_VERSION/BepInEx/config/BepInEx.cfg"
printf 'old preloader\n' > "$OLD_VERSION/BepInEx/core/BepInEx.Preloader.dll"
printf 'old doorstop\n' > "$OLD_VERSION/doorstop_libs/libdoorstop.so"
mkdir -p "$OLD_VERSION/BepInEx/plugins"
printf 'keep plugin\n' > "$OLD_VERSION/BepInEx/plugins/example.dll"
mkdir -p "$OLD_VERSION/BepInEx/config"
printf 'plugin option = old\n' > "$OLD_VERSION/BepInEx/config/Example.cfg"
mkdir -p "$OLD_VERSION/BepInEx/cache"
printf 'rebuildable cache\n' > "$OLD_VERSION/BepInEx/cache/cache.dat"
mkdir -p "$OLD_VERSION/BepInEx/patchers"
printf 'rebuildable patcher\n' > "$OLD_VERSION/BepInEx/patchers/patcher.dll"
printf 'old shared log\n' > "$OLD_VERSION/BepInEx/LogOutput.log"
ln -s "BepInEx_linux_x64_5.4.23.5/" "$BEPINEX_DIR/current"
cp "$ROOT/bepinex_upgrade.sh" "$TEST_ROOT/bepinex_upgrade.sh"
mkdir -p "$TEST_ROOT/lib"
cp "$ROOT/lib/config.sh" "$ROOT/lib/bepinex.sh" "$TEST_ROOT/lib/"
sed -i 's/^vss_bepinex_prepare_profile() {/vss_bepinex_prepare_profile_original() {/' \
    "$TEST_ROOT/lib/bepinex.sh"
cat >> "$TEST_ROOT/lib/bepinex.sh" <<'HELPER'
vss_bepinex_prepare_profile() {
    if [[ -n "${VSS_TEST_FAIL_IMAGE:-}" && "$2" == "$VSS_TEST_FAIL_IMAGE" ]]; then
        printf 'Injected post-switch profile sync failure\n' >&2
        return 1
    fi
    vss_bepinex_prepare_profile_original "$@"
}
HELPER
touch "$TEST_ROOT/crash.log"
cat > "$TEST_ROOT/.env" <<EOF
VSS_COMMON_CONFIG_VERSION=3
VSSDIR="$TEST_ROOT"
VALHEIMSERVERLOGDIR="$TEST_ROOT/valheim-logs.d"
EOF

create_profile() {
    local name="$1"
    local enabled="$2"
    cat > "$TEST_ROOT/.env.$name" <<EOF
VHSERVERWORLD="$name"
VSSBEPINEXENABLED=$enabled
VSSBEPINEXDIR="\$VSSDIR/bepinex/current/"
VSSBEPINEXLOGOUTPUT="\$VSSBEPINEXDIR/BepInEx/LogOutput.log"
EOF
}
create_profile Alpha 1
create_profile Beta 1
create_profile Disabled 0

make_fixture() {
    local version="$1"
    local archive="$TMPDIR_UPGRADE/BepInEx_linux_x64_${version}.zip"

    base64 -d "$ROOT/tests/fixtures/bepinex-image.zip.base64" > "$archive"
    printf '{\n  "assets": [\n    {"browser_download_url": "%s/%s"}\n  ]\n}\n' \
        "$FIXTURE_BASE_URL" "${archive##*/}" > "$TMPDIR_UPGRADE/release-${version}.json"
}

make_fixture 5.4.23.6
if ! BEPINEX_RELEASES_LATEST_URL="$FIXTURE_BASE_URL/release-5.4.23.6.json" \
    "$TEST_ROOT/bepinex_upgrade.sh" > "$TMPDIR_UPGRADE/upgrade.out" 2> "$TMPDIR_UPGRADE/upgrade.err"; then
    cat "$TMPDIR_UPGRADE/upgrade.err" >&2
    exit 1
fi

if [[ "$(readlink "$BEPINEX_DIR/current")" != 'BepInEx_linux_x64_5.4.23.6/' ]]; then
    echo "FAIL: current symlink was not switched to the downloaded image" >&2
    exit 1
fi
if [[ -e "$OLD_VERSION" ]]; then
    echo "FAIL: the previous active BepInEx image was not removed" >&2
    exit 1
fi
for profile in Alpha Beta; do
    PROFILE_ROOT="$BEPINEX_DIR/profiles/$profile"
    if [[ ! -f "$PROFILE_ROOT/BepInEx/plugins/example.dll" ]] ||
       [[ "$(cat "$PROFILE_ROOT/BepInEx/plugins/example.dll")" != 'keep plugin' ]]; then
        printf 'FAIL: legacy plugin was not migrated to profile %s\n' "$profile" >&2
        exit 1
    fi
    if [[ ! -f "$PROFILE_ROOT/BepInEx/config/Example.cfg" ]] ||
       [[ "$(cat "$PROFILE_ROOT/BepInEx/config/Example.cfg")" != 'plugin option = old' ]]; then
        printf 'FAIL: plugin configuration was not migrated to profile %s\n' "$profile" >&2
        exit 1
    fi
    if [[ ! -L "$PROFILE_ROOT/BepInEx/core/BepInEx.Preloader.dll" ]] ||
       [[ "$(readlink "$PROFILE_ROOT/BepInEx/core/BepInEx.Preloader.dll")" != \
          "$BEPINEX_DIR/current/BepInEx/core/BepInEx.Preloader.dll" ]]; then
        printf 'FAIL: profile %s does not link the shared preloader file through current\n' "$profile" >&2
        exit 1
    fi
    if [[ -L "$PROFILE_ROOT/BepInEx/core" || -L "$PROFILE_ROOT/BepInEx/plugins" ||
          -L "$PROFILE_ROOT/BepInEx/config" || ! -L "$PROFILE_ROOT/BepInEx/config/BepInEx.cfg" ||
          ! -L "$PROFILE_ROOT/doorstop_libs/libdoorstop.so" ]]; then
        printf 'FAIL: profile %s has a shared directory or missing shared-file links\n' "$profile" >&2
        exit 1
    fi
    if [[ -e "$PROFILE_ROOT/BepInEx/LogOutput.log" ]]; then
        printf 'FAIL: shared BepInEx logs were copied into profile %s\n' "$profile" >&2
        exit 1
    fi
    if [[ -e "$PROFILE_ROOT/BepInEx/cache/cache.dat" ]]; then
        printf 'FAIL: shared BepInEx cache was copied into profile %s\n' "$profile" >&2
        exit 1
    fi
    if [[ -e "$PROFILE_ROOT/BepInEx/patchers/patcher.dll" ]]; then
        printf 'FAIL: shared BepInEx patcher was copied into profile %s\n' "$profile" >&2
        exit 1
    fi
done
if [[ -e "$BEPINEX_DIR/profiles/Disabled" ]]; then
    echo "FAIL: a disabled profile was prepared for BepInEx" >&2
    exit 1
fi
printf 'profile-specific change\n' >> "$BEPINEX_DIR/profiles/Alpha/BepInEx/config/Example.cfg"
if [[ "$(cat "$BEPINEX_DIR/profiles/Beta/BepInEx/config/Example.cfg")" != 'plugin option = old' ]]; then
    echo "FAIL: changing one profile's plugin config changed another profile" >&2
    exit 1
fi
CONFIG="$BEPINEX_DIR/current/BepInEx/config/BepInEx.cfg"
for expected in \
    'UnityLogListening = true' \
    'LogConsoleToUnityLog = true' \
    'StandardOutType = StandardOut' \
    'WriteUnityLog = true' \
    'AppendLog = false' \
    'Enabled = true' \
    'LogLevels = Fatal, Error, Warning, Message, Info' \
    'NewUpstreamOption = preserve-me'; do
    if ! grep -Fxq "$expected" "$CONFIG"; then
        printf 'FAIL: expected config setting missing: %s\n' "$expected" >&2
        exit 1
    fi
done
if find "$BEPINEX_DIR" -maxdepth 1 -name '.upgrade.*' -print -quit | grep -q .; then
    echo "FAIL: temporary download/archive files were not cleaned up" >&2
    exit 1
fi

make_fixture 5.4.23.9
if VSS_TEST_FAIL_IMAGE="$BEPINEX_DIR/BepInEx_linux_x64_5.4.23.9" \
    BEPINEX_RELEASES_LATEST_URL="$FIXTURE_BASE_URL/release-5.4.23.9.json" \
    "$TEST_ROOT/bepinex_upgrade.sh" > "$TMPDIR_UPGRADE/rollback.out" 2> "$TMPDIR_UPGRADE/rollback.err"; then
    echo "FAIL: post-switch profile synchronization failure did not fail the upgrade" >&2
    exit 1
fi
ROLLBACK_OLD_VERSION="$BEPINEX_DIR/BepInEx_linux_x64_5.4.23.6"
if [[ "$(readlink "$BEPINEX_DIR/current")" != 'BepInEx_linux_x64_5.4.23.6/' ||
      ! -d "$ROLLBACK_OLD_VERSION" ]]; then
    echo "FAIL: post-switch synchronization failure did not restore current and retain the previous image" >&2
    cat "$TMPDIR_UPGRADE/rollback.err" >&2
    exit 1
fi
if ! grep -Fq 'previous image was retained' "$TMPDIR_UPGRADE/rollback.err"; then
    echo "FAIL: post-switch synchronization failure did not report the rollback outcome" >&2
    exit 1
fi

NEW_VERSION="$BEPINEX_DIR/BepInEx_linux_x64_5.4.23.7"
cp -a "$BEPINEX_DIR/BepInEx_linux_x64_5.4.23.6" "$NEW_VERSION"
sed -i '/^AppendLog =/d' "$NEW_VERSION/BepInEx/config/BepInEx.cfg"
make_fixture 5.4.23.7
if BEPINEX_RELEASES_LATEST_URL="$FIXTURE_BASE_URL/release-5.4.23.7.json" \
    "$TEST_ROOT/bepinex_upgrade.sh" > "$TMPDIR_UPGRADE/invalid.out" 2> "$TMPDIR_UPGRADE/invalid.err"; then
    echo "FAIL: upgrade accepted a release missing a required VSS setting" >&2
    exit 1
fi
if [[ "$(readlink "$BEPINEX_DIR/current")" != 'BepInEx_linux_x64_5.4.23.6/' ]]; then
    echo "FAIL: current symlink changed after invalid configuration" >&2
    exit 1
fi

for profile in Alpha Beta Disabled; do
    sed -i 's/^VSSBEPINEXENABLED=.*/VSSBEPINEXENABLED=0/' "$TEST_ROOT/.env.$profile"
done
mkdir -p "$BEPINEX_DIR/current/BepInEx/plugins"
printf 'shared plugin\n' > "$BEPINEX_DIR/current/BepInEx/plugins/shared.dll"
make_fixture 5.4.23.8
if BEPINEX_RELEASES_LATEST_URL="$FIXTURE_BASE_URL/release-5.4.23.8.json" \
    "$TEST_ROOT/bepinex_upgrade.sh" > "$TMPDIR_UPGRADE/no-profile.out" 2> "$TMPDIR_UPGRADE/no-profile.err"; then
    echo "FAIL: upgrade discarded shared plugins when no profile was enabled" >&2
    exit 1
fi
if [[ "$(readlink "$BEPINEX_DIR/current")" != 'BepInEx_linux_x64_5.4.23.6/' ]] ||
   [[ ! -f "$BEPINEX_DIR/BepInEx_linux_x64_5.4.23.6/BepInEx/plugins/shared.dll" ]]; then
    echo "FAIL: upgrade changed or removed the active image without a migration target" >&2
    exit 1
fi

echo "BepInEx image upgrade OK"
