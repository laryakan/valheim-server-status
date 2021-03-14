Simplest server monitoring using basic bash command and libs.
All mandatory binaries, or the very very most,  are included with distro.

> Seems like **./setup** bugs has been fixed

> Actually, your server will not update automatically. This is possible by uncommenting the **ExecStartPre=**, if you are using our service, in the **./systemd** directory
> I will add an option in the **./setup** soon to automate it

# VALHEIM SERVER MONITORING aka VSM

## Quick launch
>**git clone ...**

>**cd valheim-server-monitoring**

>**./setup** (bash script)

### Setup
![menu](https://github.com/laryakan/valheim-server-monitoring/raw/main/screenshots/vsm-menu.JPG?raw=true)
The setup will guide you into setting be everything in order, step by step.

You can check the setup completion at any time with option **1** (in any menu).
You can also scroll up to previous views.

>**Something really important for every VSM version is to pipe your server onto the logs filter at repository root.**
>Except for CPU and RAM usage, all server info will come through logs. The logs filter brings a low level log management to Valheim.
>VSM comes with a custom server launcher directly piped to the log filter (it's in the **./launcher** directory).

### Regular usage
- setup wanted Valheim server logs directory (default is **./valheim-logs.d**) with option **2**
- setup wanted Valheim server status over HTTP URL (default is **http://127.0.0.1:8181**) with option **3**
> This step is important for serving status with ncat, and also for the link in your future Discord status, setup a public host

- setup current Discord webhook URL with option **4**
- setup 'how many' wanted last logs on your Discord channel with option **5**
- force Discord webhook update with option **6** -> then go to your discord to get the messages ID just posted by the webhook
- setup current Discord webhook status message id with option **7**
- setup current Discord webhook last logs message id with option **8**
- setup current Valheim server directory with option **10** -> this is to find the server, and know where to do future update
  - can be auto set with option **15** as described in the next chapter
- setup wanted Valheim server listening port with option **11** -> this is only usefull for custom launcher
  - can be auto set with option **15** as described in the next chapter
- setup wanted Valheim server name with option **12** -> this is only usefull for custom launcher
  - can be auto set with option **15** as described in the next chapter
- setup wanted Valheim server world nam ewith option **13** -> this is only usefull for custom launcher
  - can be auto set with option **15** as described in the next chapter
- setup wanted Valheim server password with option **14** -> this is only usefull for custom launcher
  - can be auto set with option **15** as described in the next chapter
- Go into the service menu with option **20**
  - setup your env user who will execute services with option **2**
    - this can be auto set in the main menu with option **15** if you followed the steps described in the next chapter
  - setup your Valheim server launcher path with option **3**, default is the VSM custom launcher which include logs-filter piping
    - do this only if you have your own launcher piped on the logs filter
  - activate the Discord webhook update cron with option **4**
  - activate logrotate on Valheim server logs with option **5** (without sudo, the setup will tell you how to do it)
  - add and activate valheim-server.service (your server through service) with option **6** (without sudo, the setup will tell you how to do it)
    - be sure to me sudoer or root when executing this option, and be sure no service with that name already exist
  - add and activate vsm.http.service (server status over HTTP) with option **7** (without sudo, the setup will tell you how to do it)
    - be sure to me sudoer or root when executing this option, and be sure no service with that name already exist

## Already have a Valheim server ?
You have 2 way to activate **VSM - Valheim server monitoring** if you already have a server.
- Leave your own launcher and use our launcher by following the **Ultra quick start** described below

or
- Pipe your launcher on our log filter, by adding this at the end of the line of your launcher
> your_valheim_server_launch \\
> 1\> \>( tee -a \>("<path/to/logfilter>") ) \\
> 2\> \>( tee -a "<path/to/logdir>/\`date +%Y-%m-%d\`.stderr.log" \>&2 )

- setup vsm.http.service in **./setup** option **20** then **7** (only if you want your server status displaying over HTTP)
- follow **Discord Valheim Server Status** chapter steps
> avoid setting up the **valheim-server.service** from our **./setup** if you're not using our custom launcher. It should work if you've set **VHSERVERDIR** and your own launcher in **VHSERVERLAUNCHER** but it's still risky.

### Ultra quick start, if you are sure to trust scripts and default values
>This path required you to launch you Valheim server manually, without any service set, in another shell
- clone repository, starting from version 2, I recommend to clone in your executing Valheim server user home directory under the ~/.vsm directory, go inside dir
- if you already have a running Valheim server, disable/delete/daemon-reload/reset-failed eventual services you've set to start it and start you server manually. Our script will search for running **valheim_server** to get all launch parameters.
- launch **./setup** and directly enter the option **15** -> this will sniff your running server parameters to setup our custom launcher
- once done, stop your current Valheim server: this is important since our script will launch another server
- if you're not sudoer, leave the **./setup**, change account or go in root
- in **./setup**, go in service menu, option **20**
- activate the Valheim-server.service with option **6** -> this will create a service bond to our custom_launcher
- then activate the vsm.http.service with option **7**
> Once done, your Valheim server should be running as it was, but this time with a launcher piped on our logs-filter
> you can now set your Discord webhook as described below


### Discord Valheim Server Status
![discord-status](https://github.com/laryakan/valheim-server-monitoring/raw/main/screenshots/vsm-discord-status.JPG?raw=true)![discord-logs](https://github.com/laryakan/valheim-server-monitoring/raw/main/screenshots/vsm-discord-logs.JPG?raw=true)
- If you want to have info like online player and incoming new features, you absolutely need to use the logs filter to manage logs
- Go to Discord, create a webhook [How to ?](https://help.dashe.io/en/articles/2521940-how-to-create-a-discord-webhook-url) and enable developer mode [How to ?](https://www.followchain.org/copy-message-id-discord/)
- Copy your webhook URL (containing webhook id and webhook token)
- Go into the **./setup**, then option **4**
- Paste your webhook URL (webhook ID and webhook Token will be automatically determined)
- Set up, with option **5**, how many logs do you want the webhook to publish (if wanted, or set a **0** if not wanted)
- Force a Discord update with option **6**
- Go to the webhook channel, locate his messages, copy messages ID [How to ?](https://www.followchain.org/copy-message-id-discord/)
- Go into the **./setup**, then option **7** (for status), and option **8** (for logs)
- Paste messages ID in the respective options (webhook are not regular bots, can only edit their own message and needs IDs to do it)
- Force a Discord update with option **6** to check if messages are updated and not created
- Go into the **./setup**, then option **20** (to enter the service menu), then option **4** to setup update frequency (integer in minutes)
> Setting up a frequency >0 will automatically create a cron to update your server status on Discord. Set the frequency to 0 to remove auto-update.


## Uninstall
If you want to remove component that the setup has created :
- ./setup.sh
- go in the uninstall menu with option **30**
  - you can remove evething at once with option **10** or use individual options **2**,**3**,**4**,**5**
>The ./setup.sh can only remove things he has done for you. You can check up what the setup has automated by using option **1**.

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

### Logs filter through custom Valheim Server Launch
- tee (not mandatory if you redirect logs by other means)
- logrotate (if you want it)

### HTTP Status
- ncat

### Services
- systemctl

### Discord webhook
- curl

