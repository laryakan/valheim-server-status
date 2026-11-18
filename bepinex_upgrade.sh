#!/bin/bash

set -uo pipefail

VSSDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BEPINEX_DIR="$VSSDIR/bepinex"
CURRENT_LINK="$BEPINEX_DIR/current"
CRASH_LOG="$VSSDIR/crash.log"
RELEASES_LATEST_URL="${BEPINEX_RELEASES_LATEST_URL:-https://api.github.com/repos/BepInEx/BepInEx/releases/latest}"
WORK_DIR=''

fail() {
    local message="$1"
    printf 'Error: %s\n' "$message" >&2
    printf '%s [bepinex_upgrade] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$CRASH_LOG"
    exit 1
}

cleanup() {
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR"
    fi
}
trap cleanup EXIT

for command_name in wget unzip awk mktemp mv ln readlink; do
    command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

[[ -d "$BEPINEX_DIR" ]] || fail "BepInEx directory not found: $BEPINEX_DIR"
if [[ -e "$CURRENT_LINK" && ! -L "$CURRENT_LINK" ]]; then
    fail "$CURRENT_LINK exists and is not a symbolic link; refusing to replace it"
fi

WORK_DIR="$(mktemp -d "$BEPINEX_DIR/.upgrade.XXXXXX")" || fail "Could not create a temporary directory in $BEPINEX_DIR"

if ! wget -q -O "$WORK_DIR/release.json" "$RELEASES_LATEST_URL"; then
    fail "Could not download the latest BepInEx release metadata from $RELEASES_LATEST_URL"
fi

ASSET_URL="$(awk -F '"' '
    /"browser_download_url"[[:space:]]*:/ && /BepInEx_linux_x64_[^"]*\.zip/ {
        print $4
        exit
    }
' "$WORK_DIR/release.json")"
[[ -n "$ASSET_URL" ]] || fail "The latest release does not provide a BepInEx Linux x64 ZIP asset"

ASSET_NAME="${ASSET_URL##*/}"
if [[ ! "$ASSET_NAME" =~ ^BepInEx_linux_x64_[A-Za-z0-9._-]+\.zip$ ]]; then
    fail "Unexpected Linux x64 asset name: $ASSET_NAME"
fi
VERSION_DIR="${ASSET_NAME%.zip}"
ARCHIVE="$WORK_DIR/$ASSET_NAME"

if ! wget --show-progress -O "$ARCHIVE" "$ASSET_URL"; then
    fail "Could not download BepInEx package: $ASSET_URL"
fi
if ! unzip -tqq "$ARCHIVE"; then
    fail "Downloaded BepInEx archive is invalid: $ASSET_NAME"
fi
if ! unzip -Z1 "$ARCHIVE" > "$WORK_DIR/archive-files"; then
    fail "Could not inspect downloaded BepInEx archive: $ASSET_NAME"
fi
while IFS= read -r archive_entry; do
    case "$archive_entry" in
        /*|..|../*|*/../*|*/..|[A-Za-z]:/*)
            fail "Unsafe path in BepInEx archive: $archive_entry"
            ;;
    esac
done < "$WORK_DIR/archive-files"

INSTALL_DIR="$BEPINEX_DIR/$VERSION_DIR"
if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
    [[ -d "$INSTALL_DIR" && ! -L "$INSTALL_DIR" ]] || fail "Existing package path is not a regular directory: $INSTALL_DIR"
    [[ -f "$INSTALL_DIR/BepInEx/config/BepInEx.cfg" ]] || fail "Existing package is incomplete: $INSTALL_DIR"
    [[ -f "$INSTALL_DIR/BepInEx/core/BepInEx.Preloader.dll" ]] || fail "Existing package is incomplete: $INSTALL_DIR"
    [[ -f "$INSTALL_DIR/doorstop_libs/libdoorstop.so" ]] || fail "Existing package is incomplete: $INSTALL_DIR"
else
    mkdir "$WORK_DIR/package" || fail "Could not create a package staging directory"
    if ! unzip -q "$ARCHIVE" -d "$WORK_DIR/package"; then
        fail "Could not extract BepInEx archive: $ASSET_NAME"
    fi
    [[ -f "$WORK_DIR/package/BepInEx/config/BepInEx.cfg" ]] || fail "Archive has no BepInEx/config/BepInEx.cfg"
    [[ -f "$WORK_DIR/package/BepInEx/core/BepInEx.Preloader.dll" ]] || fail "Archive has no BepInEx/core/BepInEx.Preloader.dll"
    [[ -f "$WORK_DIR/package/doorstop_libs/libdoorstop.so" ]] || fail "Archive has no doorstop_libs/libdoorstop.so"
    if ! mv -- "$WORK_DIR/package" "$INSTALL_DIR"; then
        fail "Could not install package into $INSTALL_DIR"
    fi
fi

CONFIG_FILE="$INSTALL_DIR/BepInEx/config/BepInEx.cfg"
if [[ -L "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$(readlink -f -- "$CONFIG_FILE")" || fail "Could not resolve BepInEx.cfg symlink in $INSTALL_DIR"
fi
[[ -f "$CONFIG_FILE" ]] || fail "BepInEx configuration file not found: $CONFIG_FILE"

CONFIG_TEMP="$(mktemp "${CONFIG_FILE}.XXXXXX")" || fail "Could not create a temporary BepInEx.cfg"
if ! awk '
    function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
    }
    function required_value(section, key) {
        if (section == "Logging" && key == "UnityLogListening") return "true"
        if (section == "Logging" && key == "LogConsoleToUnityLog") return "true"
        if (section == "Logging.Console" && key == "StandardOutType") return "StandardOut"
        if (section == "Logging.Console" && key == "LogLevels") return "Fatal, Error, Warning, Message, Info"
        if (section == "Logging.Disk" && key == "WriteUnityLog") return "true"
        if (section == "Logging.Disk" && key == "AppendLog") return "false"
        if (section == "Logging.Disk" && key == "Enabled") return "true"
        if (section == "Logging.Disk" && key == "LogLevels") return "Fatal, Error, Warning, Message, Info"
        return ""
    }
    BEGIN {
        required[1] = "Logging" SUBSEP "UnityLogListening"
        required[2] = "Logging" SUBSEP "LogConsoleToUnityLog"
        required[3] = "Logging.Console" SUBSEP "StandardOutType"
        required[4] = "Logging.Console" SUBSEP "LogLevels"
        required[5] = "Logging.Disk" SUBSEP "WriteUnityLog"
        required[6] = "Logging.Disk" SUBSEP "AppendLog"
        required[7] = "Logging.Disk" SUBSEP "Enabled"
        required[8] = "Logging.Disk" SUBSEP "LogLevels"
    }
    /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
        section = $0
        sub(/^[[:space:]]*\[/, "", section)
        sub(/\][[:space:]]*$/, "", section)
        section = trim(section)
        print
        next
    }
    {
        line = $0
        trimmed = trim(line)
        if (trimmed == "" || trimmed ~ /^[#;]/ || index(trimmed, "=") == 0) {
            print
            next
        }

        separator = index(trimmed, "=")
        key = trim(substr(trimmed, 1, separator - 1))
        value = required_value(section, key)
        if (value == "") {
            print
            next
        }

        count[section SUBSEP key]++
        print key " = " value
    }
    END {
        failed = 0
        for (i = 1; i <= 8; i++) {
            if (count[required[i]] != 1) {
                split(required[i], parts, SUBSEP)
                printf "Expected exactly one [%s] %s setting in BepInEx.cfg, found %d\n", parts[1], parts[2], count[required[i]] > "/dev/stderr"
                failed = 1
            }
        }
        if (failed) exit 1
    }
' "$CONFIG_FILE" > "$CONFIG_TEMP"; then
    rm -f -- "$CONFIG_TEMP"
    fail "Could not enforce VSS logging settings in $CONFIG_FILE"
fi
if ! chmod --reference="$CONFIG_FILE" "$CONFIG_TEMP"; then
    rm -f -- "$CONFIG_TEMP"
    fail "Could not preserve permissions on $CONFIG_FILE"
fi
if ! mv -f -- "$CONFIG_TEMP" "$CONFIG_FILE"; then
    rm -f -- "$CONFIG_TEMP"
    fail "Could not update $CONFIG_FILE"
fi

LINK_TEMP="$WORK_DIR/current"
if ! ln -s "$VERSION_DIR/" "$LINK_TEMP"; then
    fail "Could not create temporary current symlink"
fi
if ! mv -Tf -- "$LINK_TEMP" "$CURRENT_LINK"; then
    fail "Could not switch $CURRENT_LINK to $VERSION_DIR"
fi

printf 'BepInEx image upgraded to %s\n' "$VERSION_DIR"
printf 'VSS logging settings enforced in %s\n' "$CONFIG_FILE"
printf 'Previous version directories were retained; plugins are not migrated or modified.\n'
