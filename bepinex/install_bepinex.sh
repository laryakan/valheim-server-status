#!/bin/bash

# Prepare the active BepInEx image for this profile, downloading the latest release if needed.

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$CWD/../lib/config.sh"
vss_load_config "$CWD/.." || exit 1
source "$CWD/../lib/bepinex.sh"

if [[ "${VSSBEPINEXENABLED:-0}" != "1" ]]; then
    printf 'BepInEx is disabled for profile %s; enable it in .env.%s before installing.\n' \
        "$VSS_SERVER_NAME" "$VSS_SERVER_NAME" >&2
    exit 1
fi

IMAGE_DIR="$VSSDIR/bepinex/current"
if [[ -e "$IMAGE_DIR" && ! -L "$IMAGE_DIR" ]]; then
    printf 'BepInEx current path is not a symbolic link: %s\n' "$IMAGE_DIR" >&2
    exit 1
fi
if [[ ! -L "$IMAGE_DIR" || ! -e "$IMAGE_DIR" ]]; then
    printf 'No active BepInEx image found; downloading the latest release.\n' >&2
    if ! "$VSSDIR/bepinex_upgrade.sh"; then
        printf 'Could not download or install the BepInEx image needed by profile %s.\n' \
            "$VSS_SERVER_NAME" >&2
        exit 1
    fi
fi
if [[ ! -L "$IMAGE_DIR" || ! -d "$IMAGE_DIR" ]]; then
    printf 'BepInEx upgrade did not create a usable current image: %s\n' "$IMAGE_DIR" >&2
    exit 1
fi

LEGACY_IMAGE_DIR="${VSS_BEPINEX_LEGACY_IMAGE:-$IMAGE_DIR}"
vss_bepinex_prepare_profile "$VSSBEPINEXDIR" "$IMAGE_DIR" "$LEGACY_IMAGE_DIR" || exit 1
vss_bepinex_remove_legacy_server_links "$VHSERVERDIR" || {
    printf 'Could not remove legacy VSS BepInEx links from %s\n' "$VHSERVERDIR" >&2
    exit 1
}

printf 'BepInEx is prepared for profile %s.\n' "$VSS_SERVER_NAME"
printf 'Plugins/mods: %s/BepInEx/plugins\n' "$VSSBEPINEXDIR"
printf 'Plugin configuration: %s/BepInEx/config (BepInEx.cfg is shared)\n' "$VSSBEPINEXDIR"
