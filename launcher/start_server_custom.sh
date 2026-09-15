#!/bin/bash
# Basic env init
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
exec 2>>"$CWD/../crash.log"

# Test by-pass
if [ "${DEBUGMODE:-0}" -eq 0 ];
then
  source "$CWD/../.env"
else
  source "$CWD/../.env.test"
fi

export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

if [ "${VSSBEPINEXENABLED:-0}" -eq 1 ];
then
  # BepInEx-specific settings
  ####
  export DOORSTOP_ENABLED=1
  export DOORSTOP_TARGET_ASSEMBLY="$VHSERVERDIR/BepInEx/core/BepInEx.Preloader.dll"

  export LD_LIBRARY_PATH="$VHSERVERDIR/doorstop_libs:$LD_LIBRARY_PATH"
  export LD_PRELOAD="libdoorstop.so:$LD_PRELOAD"
  ####
fi



TODAY=`date +%Y-%m-%d`

echo "Server running through VSS custom launcher, you can find logs in $VALHEIMSERVERLOGPATH"
echo "Starting server PRESS CTRL-C to exit (or stop the service if you have one)"

if [ ! -f "$CWD/launcher-args" ]; then
  cp "$CWD/../examples/launcher-args" "$CWD/launcher-args"
fi

# Tip: Make a local copy of this script to avoid it being overwritten by steam.
# NOTE: Minimum password length is 5 characters & Password cant be in the server name.
# NOTE: You need to make sure the ports 2456-2458 (or the one specified +2) is being forwarded to
#   your server through your local router & firewall.
# Redirect stdout to log-filter and stderr to another file
LAUNCH_ARGS=(
  -nographics
  -batchmode
  -name "$VHSERVERNAME"
  -port "$VHSERVERPORT"
  -world "$VHSERVERWORLD"
  # -world_seed DO NOT APPEAR TO WORK, if you want to set a seed, you need to do it in the world creation process with a local client (google how to do it)
  # -world_seed "$VHSERVERSEED"
  -savedir "$VHSERVERSAVEDIR"
  -password "$VHSERVERPASSWD"
  $( cat $CWD/launcher-args)
  # Do not use -logfile "$VALHEIMSERVERLOGDIR/$TODAY.log" because it will break the log filter
  #-logFile "$VALHEIMSERVERLOGDIR/$TODAY.log"
)

if [ "${VHSERVERCROSSPLAY:-0}" = "1" ]; then
  LAUNCH_ARGS+=( -crossplay )
fi

if [ ! "${DEBUGMODE:-0}" -eq 0 ];
then
  echo "$VHSERVERDIR/valheim_server.x86_64" "${LAUNCH_ARGS[@]}"

  echo -e "Bepinex tail debug : \n"
  echo "tail -fqn0 \"$VSSBEPINEXLOGOUTPUT\"  1> >( \"$VSSLOGFILTER\" )"
  export LD_LIBRARY_PATH=$templdpath
  exit 0
fi

if [ "${VSSBEPINEXENABLED:-0}" -eq 1 ];
then
  # Launch server, log will be captured by the VSS pipe service your have to "./setup" (hint int the phrase)
  "$VHSERVERDIR/valheim_server.x86_64" "${LAUNCH_ARGS[@]}"
else
  ### Standard launch command, with stdout and stderr redirected to log filter scripts
  "$VHSERVERDIR/valheim_server.x86_64" "${LAUNCH_ARGS[@]}" \
      1> >( "$VSSLOGFILTER" ) \
      2> >( "$VSSERRFILTER" )
fi

export LD_LIBRARY_PATH=$templdpath
