#!/bin/bash

# This script purpose is to activate BepInEx_Valheim packaged version (symlink ./current on the used version) for VSS
# Other version can be downloaded from https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/versions
# Manual installation here https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$CWD/../lib/config.sh"
vss_load_config "$CWD/.." || exit 1
source "$CWD/../lib/bepinex.sh"

vss_bepinex_remove_legacy_server_links "$VHSERVERDIR" || {
    printf 'Could not remove legacy VSS BepInEx links from %s\n' "$VHSERVERDIR" >&2
    exit 1
}

printf 'BepInEx is disabled for profile %s. Its profile files were retained at %s.\n' \
    "$VSS_SERVER_NAME" "$VSSBEPINEXDIR"
