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

## Discord status setup

![discord-status](https://github.com/laryakan/valheim-server-status/raw/main/screenshots/vss-discord-status.JPG?raw=true)![discord-logs](https://github.com/laryakan/valheim-server-status/raw/main/screenshots/vss-discord-logs.JPG?raw=true)

Quick checklist:

1. Create a Discord webhook in the target channel.
2. Enable developer mode in Discord.
3. Copy the webhook URL.
4. Run `./setup` and open the Discord menu.
5. Paste the webhook URL.
6. Optionally set how many recent logs should be published.
7. Trigger a force update.
8. Copy the message ID of the status message and the logs message.
9. Paste those IDs in the setup menu.
10. Trigger another update to verify that the message is edited instead of duplicated.

> If the status message has been deleted, VSS will create a new message automatically and log the event to `stderr` / `crash.log`.

> Set the cron frequency to `0` to disable automatic updates.

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
