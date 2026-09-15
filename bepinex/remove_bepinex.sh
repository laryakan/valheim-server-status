#!/bin/bash

# This script purpose is to activate BepInEx_Valheim packaged version (symlink ./current on the used version) for VSS
# Other version can be downloaded from https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/versions
# Manual installation here https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
exec 2>>"$CWD/../crash.log"
if [ "${DEBUGMODE:-0}" -eq 1 ];
then
   source "$CWD/../.env.test"
else
   source "$CWD/../.env"
fi

BEPINEXFILES=$( ls -1tr "$VSSBEPINEXDIR/" 2>/dev/null )

echo "BepInEx_Valheim files found in $VSSBEPINEXDIR:"
for file in $BEPINEXFILES; do
    if [ "${DEBUGMODE:-0}" -eq 1 ];
    then
        echo "DEBUG: Removed link to $VSSBEPINEXDIR/$file from $VHSERVERDIR/$file"
        continue
    fi
    if [ ! -e "$VHSERVERDIR/$file" ]; then
        continue
    fi
    rm "$VHSERVERDIR/$file"
done

echo "Remember to set VSSBEPINEXENABLED=0 in your .env file to disable BepInEx_Valheim for VSS : Can be done through ./setup"
