Simplest server monitoring using basic bash command and libs.
All mandatory binaries, or the very very most,  are included with distro.

## Quick launch
>**git clone ...**

>**cd valheim-server-monitoring**

>**grep -n "<.*>" ./**

To know which file/line you have to edit to make things works.

Most scripts will search your logs inside **./valheim-logs.d**, if you decided not to redirect logs inside it depending on your custom server launch (example in **/start_server_custom.sh.example**), keep in mind that you should have to modify path inside script based on logs 

>**grep -n "valheim-logs.d" ./***

to know which files are based on this path.

### Valheim Server as a service
>**ln -s </path/to/valheim-server.service> /etc/systemd/system/valheim-server.service**

>**sudo systemctl daemon-reload**

>**sudo service valheim-server start**

### Valheim Server status over HTTP as a service
>**ln -s </path/to/valheim-server.status.http.service> /etc/systemd/system/valheim-server.status.http.service**

>**sudo systemctl daemon-reload**

>**sudo service valheim-server.status.http start**

By default, ncat is listening on port 8181, remember that when opening ufw and redirect port the right way

### logrotate
>**ln-s </path/to/valheim-logs.logrotate> /etc/logrotate.d/valheim**

### Discord Valheim Server Status
- Go to Discord, create a webhook and enable developper mode
- Copy your webhook URL (containing webhook id and webhook token)
- then update *WEBHOOKID* and *WEBHOOKTOKEN* in *./valheim-server.webhook.json.sender*
- Launch *./valheim-server.update-discord* a single time
- Go to your discord server/channel and copy the status message id just posted by your webhook-bot, past it in *./valheim-server.webhook.status-message-id*
- Go to your discord server/channel and copy the status message id just posted by your webhook-bot, past it in *./valheim-server.webhook.last-logs-message-id*
- Check that *./valheim-server.update-discord* is UPDATING existing message and don't create new ones
- If everything is ok, you can create a cron to auto-update server status, i recommend every 5 minutes :
>**crontab -e**

and add bottom
>***/5 * * * * </path/to/valheim-server.update-discord>**

## Mandatory
### All
- Linux bash !
- steamcmd
- valheim_dedicated_server
- dirname
- cut
- sed
- date
- grep
- pgrep
- cat
- test
- exit
- top
- awk
- tail
- head
- echo
- ps

### Logs filter through custom Valheim Server Launch
- tee (not mandatory if you redirect logs by other means)
- logrotate (if you want if)

### HTTP Status
- ncat

### Services
- systemctl

### Discord webhook
- curl

