# VALHEIM SERVER STATUS
> Renamed from VALHEIM SERVER MONITORING

## [ULTRA QUICK START](#auto-conf-quickstart)
Existing logs ? Discord Webhook only : **./setup** -> option **5** -> option **6** -> [Discord Menu](#discord-valheim-server-status)

Simplest server status using basic bash command and libs.
All mandatory binaries, or the very very most,  are included with distro.

## Quick launch
>**git clone ...**

>**cd valheim-server-status**

>**./setup** (bash script)

### Setup
![menu](https://github.com/laryakan/valheim-server-status/raw/main/screenshots/vss-menu.JPG?raw=true)
The setup will guide you into setting be everything in order, step by step.

You can check the setup completion at any time with option **1** (in any menu).
You can also scroll up to previous views.

>**Something really important for every VSS version is to pipe your server onto the log filter at repository root.**
>Except for CPU and RAM usage, all server info will come through logs. The log filter brings a low level log management to Valheim.
>VSS comes with a custom server launcher directly piped to the log filter (it's in the **./launcher** directory).
**NEW** VSS comes now with a service providing you a **tail** pipe on existing logs if you don't want to use our custom launcher or modify your own launcher

## Already have a Valheim server ?
You have 2 way to activate **VSS - Valheim server status** if you already have a server.
- Leave your own launcher and use our launcher by following the **Ultra quick start** described below

or
- Pipe your launcher on our log filter, by adding this at the end of the line of your launcher

```bash
your_valheim_server_launch \
1> >( tee -a >("${<path/to/logfilter>}") ) \
2> >( tee -a "${<path/to/valheim-logs.d>}/`date +%Y-%m-%d`.stderr.log" >&2 )
```

or
- **NEW** Use our pipe service to pipe existing logs on our filter, following option **5** -> **6** in main menu

### Auto-conf quickstart
- clone repository, starting from version 2, I recommend to clone in your executing Valheim server user home directory under the ~/.vss directory, go inside dir
- if you already have a running Valheim server, disable/delete/daemon-reload/reset-failed eventual services you've set to start it and start you server manually. Our script will search for running **valheim_server** to get all launch parameters.
- launch **./setup** and directly enter the option **2** then **1** in launcher menu -> this will sniff your running server parameters to setup our custom launcher
- once done, stop your current Valheim server: this is important since our script will launch another server
- if you're not sudoer, leave the **./setup**, change account or go in root
- in **./setup**, go in launcher menu, option **2**
- activate the valheim-server.service with option **7** -> this will create a service bond to our custom_launcher
> Once done, your Valheim server should be running as it was, but this time with a launcher piped on our log-filter
> you can now set your Discord webhook as described below
> you can also setup vss.http as described below

### Tail Pipe quickstart
- clone repository, starting from version 2, I recommend to clone in your executing Valheim server user home directory under the ~/.vss directory, go inside dir
- if you already have a running Valheim server, disable/delete/daemon-reload/reset-failed eventual services you've set to start it and start you server manually. Our script will search for running **valheim_server** to get all launch parameters.
- launch **./setup** and use option **5** in main menu to setup you logfile/logdir path (wildcards are valid)
- as **root** or sudoer, at the main menu, use option **6** to add and activate vss.pipe.service, this will catch interesting log from and your existing logfile/logdir
> you can now set your Discord webhook as described below
> you can also setup vss.http as described below


### Discord Valheim Server Status
![discord-status](https://github.com/laryakan/valheim-server-status/raw/main/screenshots/vss-discord-status.JPG?raw=true)![discord-logs](https://github.com/laryakan/valheim-server-status/raw/main/screenshots/vss-discord-logs.JPG?raw=true)
- If you want to have info like online player and incoming new features, you absolutely need to use the log filter to manage logs
- Go to Discord, create a webhook [How to ?](https://help.dashe.io/en/articles/2521940-how-to-create-a-discord-webhook-url) and enable developer mode [How to ?](https://www.followchain.org/copy-message-id-discord/)
- Copy your webhook URL (containing webhook id and webhook token)
- Go into the **./setup**, then option **1** to the Discord menu
- In the Discord menu, use option **1** to paste your Discord Webhook URL (webhook ID and webhook Token will be automaticaly determined)
- Set up, with option **2**, how many logs do you want the webhook to publish (if wanted, or set a **0** if not wanted)
- Force a Discord update with option **3**
- Go to the webhook channel, locate his messages, copy messages ID [How to ?](https://www.followchain.org/copy-message-id-discord/)
- In the Discord menu (**./setup** option **1**), then option **4** (for status), and option **5** (for logs, if wanted)
- Paste messages ID in the respective options (webhook are not regular bots, can only edit their own message and needs IDs to do it)
- Force a Discord update with option **3** to check if messages are updated and not created
- You can know set an auto-update for server hearbeat with option **6** using a cron
> Setting up a frequency >0 will automatically create a cron to update your server status on Discord. Set the frequency to 0 to remove the cron, so no more auto-update


## Uninstall
If you want to remove component that the setup has created :
- **./setup.sh**
- in the main menu, option **10** will remove everything supposely installed by VSS. You can remove individual component from their respective menu. sudo is required for services and log rotate.
>The ./setup.sh can only remove things he has done for you. You can check up what the setup has automated in the status top header inside the **./setup**.

## Mandatory
### All
- bash (linux bash)
- steamcmd + valheim_dedicated_server
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
#### in the future (maybe)
- trap 
- inotifywait
- jq

### Log filter through custom Valheim Server Launch
- tee (not mandatory if you redirect logs by other means)
- logrotate (if you want it)

### HTTP Status
- ncat

### Services
- systemctl

### Discord webhook
- curl

