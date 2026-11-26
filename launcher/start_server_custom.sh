#!/bin/bash
# Basic env init
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$CWD/../lib/config.sh"
vss_load_config "$CWD/.." || exit 1
source "$CWD/../lib/bepinex.sh"

export templdpath="${LD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH="./linux64${templdpath:+:$templdpath}"
export SteamAppId=892970

vss_bepinex_configure_runtime || exit 1



TODAY=`date +%Y-%m-%d`

echo "Server running through VSS custom launcher, you can find logs in $VALHEIMSERVERLOGPATH"
echo "Starting server PRESS CTRL-C to exit (or stop the service if you have one)"

if [ ! -f "$VHSERVERLAUNCHERARGS" ]; then
  cp "$CWD/../examples/launcher-args" "$VHSERVERLAUNCHERARGS"
fi

# Tip: Make a local copy of this script to avoid it being overwritten by steam.
# NOTE: Minimum password length is 5 characters & Password cant be in the server name.
# NOTE: You need to make sure the ports 2456-2457 (or the one specified +1) is being forwarded to
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
  $( cat "$VHSERVERLAUNCHERARGS")
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
