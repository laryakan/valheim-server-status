#!/bin/bash
# Basic env init
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$CWD/../.env"

export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

CWD=$(dirname "$0")
TODAY=`date +%Y-%m-%d`

echo "Server running through VSM custom launcher, you can find logs in $VALHEIMSERVERLOGSDIR"
echo "Starting server PRESS CTRL-C to exit (or stop the service if you have one)"

# Tip: Make a local copy of this script to avoid it being overwritten by steam.
# NOTE: Minimum password length is 5 characters & Password cant be in the server name.
# NOTE: You need to make sure the ports 2456-2458 (or the one specified +2) is being forwarded to
#   your server through your local router & firewall.
# Redirect stdout to logs.filter and stderr to another file
"$VHSERVERDIR/valheim_server.x86_64" \
-name "$VHSERVERNAME" \
-port $VHSERVERPORT \
-world "$VHSERVERWORLD" \
-password "$VHSERVERPASSWD" \
> >("$VSMLOGFILTER") 2> "$VALHEIMSERVERLOGSDIR/`date +%Y-%m-%d`.stderr.log"

export LD_LIBRARY_PATH=$templdpath
