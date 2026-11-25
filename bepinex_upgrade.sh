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

for command_name in wget unzip awk mktemp mv ln readlink find cp mkdir dirname rm; do
    command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

[[ -d "$BEPINEX_DIR" ]] || fail "BepInEx directory not found: $BEPINEX_DIR"
if [[ -e "$CURRENT_LINK" && ! -L "$CURRENT_LINK" ]]; then
    fail "$CURRENT_LINK exists and is not a symbolic link; refusing to replace it"
fi
source "$VSSDIR/lib/config.sh"
source "$VSSDIR/lib/bepinex.sh"

BEPINEX_REAL_DIR="$(cd -- "$BEPINEX_DIR" && pwd -P)" || fail "Could not resolve $BEPINEX_DIR"
OLD_TARGET=''
OLD_LINK_TARGET=''
if [[ -L "$CURRENT_LINK" ]]; then
    OLD_LINK_TARGET="$(readlink -- "$CURRENT_LINK")" || fail "Could not read current BepInEx link: $CURRENT_LINK"
    if [[ -e "$CURRENT_LINK" ]]; then
        OLD_TARGET="$(readlink -f -- "$CURRENT_LINK")" || fail "Could not resolve current BepInEx link: $CURRENT_LINK"
        [[ -d "$OLD_TARGET" ]] || fail "Current BepInEx target is not a directory: $OLD_TARGET"
        [[ "$(dirname -- "$OLD_TARGET")" == "$BEPINEX_REAL_DIR" ]] ||
            fail "Current BepInEx target is outside $BEPINEX_DIR; refusing to remove it"
    else
        broken_target_name="$OLD_LINK_TARGET"
        case "$broken_target_name" in
            "$BEPINEX_REAL_DIR"/*)
                broken_target_name="${broken_target_name#"$BEPINEX_REAL_DIR"/}"
                ;;
        esac
        broken_target_name="${broken_target_name%/}"
        [[ "$broken_target_name" =~ ^BepInEx_linux_x64_[A-Za-z0-9._-]+$ ]] ||
            fail "Current BepInEx link is broken and does not point to a managed package: $CURRENT_LINK"
        printf 'Warning: replacing broken BepInEx link to %s with the downloaded image.\n' \
            "$OLD_LINK_TARGET" >&2
        OLD_LINK_TARGET=''
    fi
fi

prepare_enabled_profile() (
    local profile_name="$1"
    local image_root="$2"
    local legacy_image_root="${3:-}"
    local config_policy="${4:-strict}"

    VSS_SERVER_NAME="$profile_name"
    export VSS_SERVER_NAME
    unset VSS_ENV_FILE VSS_CONFIG_LOADED VHSERVERWORLD VSSBEPINEXENABLED VSSBEPINEXDIR VSSBEPINEXLOGOUTPUT
    if ! vss_load_config "$VSSDIR"; then
        exit 2
    fi
    case "${VSSBEPINEXENABLED:-0}" in
        1)
            if ! vss_bepinex_prepare_profile "$VSSBEPINEXDIR" "$image_root" "$legacy_image_root" "$config_policy"; then
                exit 2
            fi
            exit 0
            ;;
        0|'')
            exit 1
            ;;
        *)
            printf 'Invalid VSSBEPINEXENABLED value in profile %s\n' "$profile_name" >&2
            exit 2
            ;;
    esac
)

legacy_image_has_profile_data() {
    local legacy_root="$1/BepInEx"
    local path
    local relative_path

    [[ -d "$legacy_root" ]] || return 1
    while IFS= read -r -d '' path; do
        relative_path="${path#"$legacy_root"/}"
        case "$relative_path" in
            plugins|plugins/*|config|config/*) ;;
            *) continue ;;
        esac
        case "$relative_path" in
            config/BepInEx.cfg) continue ;;
        esac
        return 0
    done < <(find "$legacy_root" \( -type f -o -type l \) -print0)
    return 1
}

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
    [[ -f "$INSTALL_DIR/libdoorstop.so" || -f "$INSTALL_DIR/doorstop_libs/libdoorstop.so" ]] ||
        fail "Existing package is incomplete: $INSTALL_DIR"
else
    mkdir "$WORK_DIR/package" || fail "Could not create a package staging directory"
    if ! unzip -q "$ARCHIVE" -d "$WORK_DIR/package"; then
        fail "Could not extract BepInEx archive: $ASSET_NAME"
    fi
    CONFIG_FILE="$WORK_DIR/package/BepInEx/config/BepInEx.cfg"
    if [[ ! -e "$CONFIG_FILE" && ! -L "$CONFIG_FILE" ]]; then
        mkdir -p "$(dirname -- "$CONFIG_FILE")" || fail "Could not create the BepInEx config directory"
        if ! cat > "$CONFIG_FILE" <<'CONFIG'
# Minimal VSS logging configuration; BepInEx adds its other defaults on first launch.
[Logging]
UnityLogListening = true
LogConsoleToUnityLog = true

[Logging.Console]
StandardOutType = StandardOut
LogLevels = Fatal, Error, Warning, Message, Info

[Logging.Disk]
WriteUnityLog = true
AppendLog = false
Enabled = true
LogLevels = Fatal, Error, Warning, Message, Info
CONFIG
        then
            fail "Could not create a default BepInEx.cfg"
        fi
    fi
    [[ -f "$CONFIG_FILE" ]] || fail "Archive has no regular BepInEx/config/BepInEx.cfg"
    [[ -f "$WORK_DIR/package/BepInEx/core/BepInEx.Preloader.dll" ]] || fail "Archive has no BepInEx/core/BepInEx.Preloader.dll"
    [[ -f "$WORK_DIR/package/libdoorstop.so" || -f "$WORK_DIR/package/doorstop_libs/libdoorstop.so" ]] ||
        fail "Archive has no root-level libdoorstop.so"
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

ENABLED_PROFILE_COUNT=0
PROFILE_IMAGE_DIR="$INSTALL_DIR"
if [[ -n "$OLD_TARGET" ]]; then
    PROFILE_IMAGE_DIR="$OLD_TARGET"
fi
for profile_file in "$VSSDIR"/.env.*; do
    [[ -f "$profile_file" ]] || continue
    case "${profile_file##*/}" in
        .env.server.dist|.env.common.dist|.env.test)
            continue
            ;;
    esac

    profile_name="${profile_file#"$VSSDIR"/.env.}"
    vss_validate_server_name "$profile_name" || continue
    # Keep conflicting profile configs intact until the new image is active.
    if prepare_enabled_profile "$profile_name" "$PROFILE_IMAGE_DIR" "$OLD_TARGET" defer; then
        ENABLED_PROFILE_COUNT=$((ENABLED_PROFILE_COUNT + 1))
    else
        profile_status=$?
        [[ "$profile_status" -eq 1 ]] && continue
        fail "Could not prepare BepInEx files for profile $profile_name"
    fi
done

if [[ -n "$OLD_TARGET" && "$ENABLED_PROFILE_COUNT" -eq 0 ]] &&
   legacy_image_has_profile_data "$OLD_TARGET"; then
    fail "The active BepInEx image contains plugins/configuration, but no enabled profile is available to receive them; the current image was not switched or removed"
fi

LINK_TEMP="$WORK_DIR/current"
if ! ln -s "$VERSION_DIR/" "$LINK_TEMP"; then
    fail "Could not create temporary current symlink"
fi
if ! mv -Tf -- "$LINK_TEMP" "$CURRENT_LINK"; then
    fail "Could not switch $CURRENT_LINK to $VERSION_DIR"
fi

PROFILE_SYNC_ERROR=''
for profile_file in "$VSSDIR"/.env.*; do
    [[ -f "$profile_file" ]] || continue
    case "${profile_file##*/}" in
        .env.server.dist|.env.common.dist|.env.test)
            continue
            ;;
    esac

    profile_name="${profile_file#"$VSSDIR"/.env.}"
    vss_validate_server_name "$profile_name" || continue
    if prepare_enabled_profile "$profile_name" "$INSTALL_DIR" "" replace; then
        continue
    else
        profile_status=$?
        [[ "$profile_status" -eq 1 ]] && continue
        PROFILE_SYNC_ERROR="$profile_name"
        break
    fi
done

if [[ -n "$PROFILE_SYNC_ERROR" ]]; then
    if [[ -n "$OLD_LINK_TARGET" ]]; then
        ROLLBACK_LINK="$WORK_DIR/current-rollback"
        if ! ln -s -- "$OLD_LINK_TARGET" "$ROLLBACK_LINK" ||
           ! mv -Tf -- "$ROLLBACK_LINK" "$CURRENT_LINK"; then
            fail "Could not prepare profile $PROFILE_SYNC_ERROR; failed to restore the previous current image. The old image was retained at $OLD_TARGET"
        fi

        for profile_file in "$VSSDIR"/.env.*; do
            [[ -f "$profile_file" ]] || continue
            case "${profile_file##*/}" in
                .env.server.dist|.env.common.dist|.env.test)
                    continue
                    ;;
            esac
            profile_name="${profile_file#"$VSSDIR"/.env.}"
            vss_validate_server_name "$profile_name" || continue
            if prepare_enabled_profile "$profile_name" "$OLD_TARGET" "" defer; then
                continue
            else
                profile_status=$?
                [[ "$profile_status" -eq 1 ]] && continue
                fail "Profile $PROFILE_SYNC_ERROR failed to prepare; current was restored, but profile $profile_name could not be resynchronized. The old image was retained."
            fi
        done
    else
        rm -f -- "$CURRENT_LINK" || fail "Profile $PROFILE_SYNC_ERROR failed to prepare and the initial current link could not be removed"
    fi
    fail "Could not synchronize shared BepInEx files for profile $PROFILE_SYNC_ERROR; the previous image was retained"
fi

INSTALL_REAL_DIR="$BEPINEX_REAL_DIR/$VERSION_DIR"
if [[ -n "$OLD_TARGET" && "$OLD_TARGET" != "$INSTALL_REAL_DIR" ]]; then
    if ! rm -rf -- "$OLD_TARGET"; then
        fail "BepInEx was switched to $VERSION_DIR, but the previous image could not be removed: $OLD_TARGET"
    fi
fi

printf 'BepInEx image upgraded to %s\n' "$VERSION_DIR"
printf 'VSS logging settings enforced in %s\n' "$CONFIG_FILE"
if [[ -n "$OLD_TARGET" && "$OLD_TARGET" != "$INSTALL_REAL_DIR" ]]; then
    printf 'Previous active image removed: %s\n' "$OLD_TARGET"
fi
printf 'Prepared %s enabled profile(s); BepInEx logs were not migrated.\n' "$ENABLED_PROFILE_COUNT"
