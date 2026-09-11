# VALHEIM SERVER STATUS

VSS is a lightweight Bash-based monitoring project for a local Valheim dedicated server.
It tracks server state, online/offline players, exposes a status page over HTTP, and can send Discord webhook updates.

## Quick start

1. Clone the repository.
2. Go inside the project directory.
3. Run `./setup`.
4. Follow the menus to configure the server, logs, Discord, and services.

## What this project does

- monitors a Valheim server process
- parses server logs to detect player connections and disconnections
- exposes CLI and HTTP status information
- optionally posts updates to Discord
- can update a single Discord message instead of creating duplicates
- logs runtime issues in `crash.log` instead of aborting the workflow

## Recommended setup path

This is the easiest and most reliable flow for most users:

1. Start with `./setup`
2. Configure the launcher settings if you already have a running Valheim server
3. Start the server through the project launcher or pipe your existing logs into `vss.log-filter`
4. Configure Discord webhook and message IDs if you want live status updates
5. Optionally enable the HTTP status page

## Important concept

The log filter is the real source of player state information.
Except for basic CPU and RAM values, most of the status is derived from Valheim logs.
If you do not pipe your server logs into `vss.log-filter`, many features will not work correctly.

> The repository includes a custom launcher in `./launcher` and a log pipe service for existing logs.

## Existing Valheim server

You have two main ways to connect an existing server to VSS:

### Option A: use the custom launcher

Use the built-in custom launcher and let VSS configure the launch parameters automatically.

### Option B: pipe your existing logs

If you keep your own launcher, add the following pattern to your Valheim start command:

```bash
your_valheim_server_launch \
1> >( tee -a >("${<path/to/logfilter>}" ) ) \
2> >( tee -a "${<path/to/valheim-logs.d>}/`date +%Y-%m-%d`.stderr.log" >&2 )
```

You can also use the project pipe service from the main menu by selecting the logs path and activating the pipe service.

## Setup flow

### Auto-config

- clone the repository in the user home directory used by the Valheim server
- stop any service that starts Valheim manually
- run `./setup`
- go to the launcher menu and use the auto-config option
- stop the running Valheim server and relaunch it through the project launcher

### Pipe mode

- configure the log file or log directory path in the main menu
- activate the pipe service
- make sure the log file is readable by the project user
- then configure Discord or HTTP status as needed

## Discord-only walkthrough

This is the simplest Discord setup when you want only webhook notifications and no HTTP status page.

### 1) Create the webhook

1. Open the Discord channel you want to use.
2. Channel settings → Integrations → Webhooks.
3. Create a webhook and copy the full URL.
4. Keep developer mode enabled so you can copy message IDs later.

### 2) Configure the project

Run:

```bash
cd /home/your-user/valheim-server-status
./setup
```

Then go to:

- Discord menu
- option 1: paste the webhook URL
- option 2: set how many recent logs to send, or `0` to disable
- option 7: enable `SENDSERVERCONNECTIONINFO` with value `1`
- option 6: set the connection-info message ID once created, or leave empty for the initial message
- option 4: set the server-status message ID once created
- option 5: set the logs message ID once created

### 3) Create the initial messages

Once the config is in place, go to the Discord menu in `./setup` and select option 3 to force a webhook update.

This creates the first Discord messages in order:

1. connection info
2. server status
3. last logs

Then copy the message IDs from Discord and save them in `.env` or through the setup menu.

You can also trigger the same update directly with:

```bash
./discord/update
```

### 4) Switch to update mode

After the initial messages exist, set:

```bash
SERVERCONNECTIONINFOMESSAGEID=<id>
STATUSMESSAGEID=<id>
LASTLOGMESSAGEID=<id>
```

Then the project will update those existing messages instead of creating duplicates.

### 5) Keep automatic updates

In the Discord menu:

- set `CRONTABWEBHOOKFREQ` to a value such as `5` for every 5 minutes
- or set it to `0` to disable automatic updates

> If a message is deleted, VSS creates a new one and logs it to `stderr` / `crash.log`.

## Log pipeline walkthrough

The log pipeline is the source of player activity and state changes.

### Recommended flow

1. Make sure the Valheim server writes to a log file or stream.
2. Point `VALHEIMSERVERLOGPATH` to a file or a directory pattern.
3. Activate the pipe service from `./setup`.
4. Ensure the log filter is receiving the server output.

### Example using a custom launcher

```bash
./launcher/start_server_custom.sh
```

The launcher writes to a log path that VSS can watch and parse.

#### Custom args launcher

First launch `./setup`, then CTRL+C to exit, this will create the file where you will be able to set custom server launcher args :

```bash
./launcher/launcher-args
```

You can find the option you can put here (for exemple) :
https://www.survivalservers.com/wiki/Valheim_Server_Settings#Presets

### Example using an existing launcher

If your server is already started elsewhere, pipe its logs into the filter:

```bash
your_valheim_server_binary -name "My Server" -world "MyWorld" -password "secret" \
  | tee -a "$HOME/valheim-server-status/valheim-logs.d/$(date +%Y-%m-%d).stdout.log"
```

Then in the project setup, set:

```bash
VALHEIMSERVERLOGPATH="$HOME/valheim-server-status/valheim-logs.d/*.log"
```

or a more specific file path if you use a single log file.

### Example with the built-in pipe service

From the main setup menu:

- choose the logs path
- activate the pipe service
- check that the log filter is running with `pgrep vss.log-filter`

Once active, player join/leave events are tracked automatically and can be posted to Discord.

## Order of Discord messages on the channel

The project sends Discord messages in this order:

1. connection info
2. server status
3. last logs

This ordering is intentional so the channel starts with a stable connection block, then the current server state, then the recent log excerpts.

A short pause is inserted between messages to keep Discord ordering consistent across updates.

## HTTP status setup

The HTTP status page is separate from the Discord status. It exposes the state of the server over HTTP and is useful if you want a simple status endpoint.

## Uninstall

If you want to remove the components created by VSS:

- run `./setup`
- use the uninstall options in the main menu
- root/sudo is required for system services and logrotate entries

> The setup removes only the components it created.

## Required tools

Install the usual Linux utilities with your package manager when needed, for example:

```bash
sudo apt install coreutils grep procps psmisc sed gawk util-linux curl dnsutils logrotate ncat
```

Exceptions:

- `bash` is already present on most Linux systems
- `steamcmd` requires extra setup and is not a standard package in every distro; see the official SteamCMD documentation: https://developer.valvesoftware.com/wiki/SteamCMD
- `valheim_dedicated_server` must be installed separately from Steam/SteamCMD. Example install command:

```bash
steamcmd +login anonymous +force_install_dir <path_to_install> +app_update 896660 validate +exit
```

### Log filter

- `tee` (usually installed with coreutils)
- `logrotate` (optional but recommended)

### HTTP status

- `ncat`

### Services

- `systemctl`

### Discord webhook support

- `curl`

## Robustness and troubleshooting

The project intentionally prefers safe defaults over hard failures.

- invalid numeric values fall back to a sensible default
- warnings and failures are sent to `stderr`
- runtime issues are appended to `crash.log` at the repository root

Common checks:

- confirm the Valheim server process is running
- confirm the log filter is receiving log lines
- check `crash.log` if the status or webhook behaves unexpectedly
- verify that the Discord message ID still exists before updating it

## Notes

- This project is intentionally Bash-first and lightweight.
- It is designed for Linux systems and service-based operation.
- For more advanced setups, prefer the custom launcher or the log pipe service.
