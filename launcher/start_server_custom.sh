#!/bin/bash
# Basic env init
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
exec 2>>"$CWD/../crash.log"

# Test by-pass
if [ -z $DEBUGMODE ];
then
  source "$CWD/../.env"
else
  source "$CWD/../.env.test"
fi

export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

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
  -world_seed "$VHSERVERSEED"
  -savedir "$VHSERVERSAVEDIR"
  -password "$VHSERVERPASSWD"
  $( cat $CWD/launcher-args)
  # Do not use -logfile "$VALHEIMSERVERLOGDIR/$TODAY.log" because it will break the log filter
  #-logFile "$VALHEIMSERVERLOGDIR/$TODAY.log"
)

if [ "${VHSERVERCROSSPLAY:-0}" = "1" ]; then
  LAUNCH_ARGS+=( -crossplay )
fi

if [ ! -z $DEBUGMODE ];
then
  echo "$VHSERVERDIR/valheim_server.x86_64" "${LAUNCH_ARGS[@]}"
  export LD_LIBRARY_PATH=$templdpath
  exit 0
fi


"$VHSERVERDIR/valheim_server.x86_64" "${LAUNCH_ARGS[@]}" \
1> >( tee -a >("$VSSLOGFILTER") ) \
2> >( tee -a "$VALHEIMSERVERLOGDIR/`date +%Y-%m-%d`.stderr.log" >&2 )


export LD_LIBRARY_PATH=$templdpath
