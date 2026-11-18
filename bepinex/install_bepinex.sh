#!/bin/bash

# This script purpose is to activate BepInEx_Valheim packaged version (symlink ./current on the used version) for VSS
# Other version can be downloaded from https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/versions
# Manual installation here https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/

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
LEGACY_IMAGE_DIR="${VSS_BEPINEX_LEGACY_IMAGE:-$IMAGE_DIR}"
vss_bepinex_prepare_profile "$VSSBEPINEXDIR" "$IMAGE_DIR" "$LEGACY_IMAGE_DIR" || exit 1
vss_bepinex_remove_legacy_server_links "$VHSERVERDIR" || {
    printf 'Could not remove legacy VSS BepInEx links from %s\n' "$VHSERVERDIR" >&2
    exit 1
}

printf 'BepInEx is prepared for profile %s.\n' "$VSS_SERVER_NAME"
printf 'Plugins/mods: %s/BepInEx/plugins\n' "$VSSBEPINEXDIR"
printf 'Plugin configuration: %s/BepInEx/config (BepInEx.cfg is shared)\n' "$VSSBEPINEXDIR"
