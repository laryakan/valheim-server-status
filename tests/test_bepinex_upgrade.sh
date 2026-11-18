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

for command_name in wget unzip ncat base64; do
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
ln -s "BepInEx_linux_x64_5.4.23.5/" "$BEPINEX_DIR/current"
cp "$ROOT/bepinex_upgrade.sh" "$TEST_ROOT/bepinex_upgrade.sh"
touch "$TEST_ROOT/crash.log"

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
if [[ ! -f "$OLD_VERSION/BepInEx/plugins/example.dll" ]] || [[ "$(cat "$OLD_VERSION/BepInEx/plugins/example.dll")" != 'keep plugin' ]]; then
    echo "FAIL: existing plugin files were changed or removed" >&2
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

echo "BepInEx image upgrade OK"
