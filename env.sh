# VMS env file, everything between "set -o allexport" and "set +o allexport" will be exported
set -o allexport
# Root dir
VMSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Valheim server dir
VHSERVERDIR=''
# Logs dir
VALHEIMSERVERLOGSDIR="$VMSDIR/valheim-logs.d"
# Connected players list
CONNECTEDPLAYERSFILE="$VMSDIR/valheim-server.online-players"
# Offline players list
OFFLINEPLAYERSFILE="$VMSDIR/valheim-server.offline-players"
# Valheim server PID; If you run more than one server, please add a PID file

### STATUS ###
#VALSERVERPID=`cat valheim-server.pid`
VALSERVERPID=`pgrep valheim_server`

### STATUS OVER HTTP ###
# Port listening for ncat valheim server status over HTTP in nreal time
STATUSPORT=8181
# Setup as a service
VMSOVERHTTP=0

### DISCORD WEBHOOK ###
# Create your webhook on the desired channel in Discord, then paste your webhook id and token here
WEBHOOKID='<your-webhook-id>'
WEBHOOKTOKEN='<your-webhook-token>'
# At first launch, the webhook will create a new message. If you want the webhook to update your message
# instead of creating new ones, paste the message id here. CAUTION: The webhook and only update its own messages
STATUSMESSAGEID=''
# If you want the webhook to send logs
SENDLASTLOGS=0
LASTLOGMESSAGEID=''
# Cront update
VMSCRONDISCORDUPDATE=0
#EOF
set +o allexport
