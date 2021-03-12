#!/bin/bash

export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

CWD=$(dirname "$0")
TODAY=`date +%Y-%m-%d`

echo "Starting server PRESS CTRL-C to exit"

# Tip: Make a local copy of this script to avoid it being overwritten by steam.
# NOTE: Minimum password length is 5 characters & Password cant be in the server name.
# NOTE: You need to make sure the ports 2456-2458 is being forwarded to your server through your local router & firewall.
# Redirect stdout to logs.filter and stderr to another file
"$CWD/valheim_server.x86_64" -name "<your-server-name>" -port 2456 -world "<your-server-world>" -password "<your-server-pwd>" > >("</path/to/valheim-logs.filter>") 2> >(tee -a "</path/to/logs/dir/like/valheim-logs.d>/`date +%Y-%m-%d`.stderr.log" >&2)

export LD_LIBRARY_PATH=$templdpath


