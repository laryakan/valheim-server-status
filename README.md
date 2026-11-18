# Valheim Server Status

VSS is a lightweight Bash-based monitoring and status tool for Valheim dedicated servers. One VSS checkout can manage multiple servers using shared scripts and a separate configuration profile for each world.

## Requirements

- Linux and Bash
- `systemctl` for system services
- `curl` for Discord webhooks
- `ncat` for the optional HTTP status endpoint
- `logrotate` for rotating VSS logs

## Server profiles

Each server is identified by its Valheim world name (`VHSERVERWORLD`) and has a configuration file named `.env.<world-name>`. The classic `.env` file is no longer an active configuration. `.env.dist` is the template used to create profiles.

Start the setup interface:

```bash
./setup
```

Choose an existing profile or create one by entering its world name. Profiles can also be listed, created, or selected directly:

```bash
./setup --list
./setup --create MyWorld
./setup MyWorld
```

Server actions can run without opening the interactive menu. Lifecycle actions use that profile's systemd unit (and may prompt for `sudo`); Discord updates use its webhook configuration:

```bash
./setup --start-server MyWorld
./setup --stop-server MyWorld
./setup --restart-server MyWorld
./setup --status-server MyWorld
./setup --discord-update MyWorld
```

The interactive setup dashboard shows the selected world, Valheim process state, ports, and installed service units. Menus are grouped by configuration, monitoring, and maintenance; the profile picker accepts a profile name, `n` to create one, or `q` to quit. It uses only Bash and standard terminal output (no additional TUI package). Colors are disabled with `NO_COLOR`, and the screen is only cleared in an interactive terminal.

World names used as profile IDs must contain only letters, numbers, dots, underscores, and hyphens, and must be unique. Valheim saves are stored in the shared `savedir` and distinguished by world name. The game's `adminlist.txt`, `bannedlist.txt`, and `permittedlist.txt` files are shared by all profiles.

Each profile gets its own launcher arguments file:

```text
launcher/launcher-args.<world-name>
```

Configuration is selected explicitly for direct commands:

```bash
VSS_SERVER_NAME=MyWorld ./discord/update
VSS_SERVER_NAME=MyWorld ./status/server-status
```

The setup interface also accepts a world name as its argument and passes the selected profile to its services and scheduled jobs.

## Migrating an existing installation

When `./setup` finds a legacy `.env` and no matching `.env.<VHSERVERWORLD>`, it renames the configuration to the new profile name, renames `launcher/launcher-args` to `launcher/launcher-args.<world-name>`, and suffixes the VSS state files in `data/`. The migration stops rather than overwriting a profile or state file that already exists.

After migration, select the profile in `./setup` and reinstall its server, pipe, and HTTP services so the new profile-specific systemd units are installed. Existing units are not automatically removed.

## Logs

VSS writes server logs using this naming convention:

```text
<date>.<world-name>.stdout.log
<date>.<world-name>.stderr.log
```

The logs are stored in `valheim-logs.d/`. A single shared logrotate configuration covers all server logs; removing one server profile does not remove that shared configuration.

The log filter is the source of player-state updates. For an existing Valheim launcher, configure its output path in the selected profile and activate that profile's pipe service from `./setup`. For the VSS launcher, configure the server and use:

```bash
VSS_SERVER_NAME=MyWorld ./launcher/start_server_custom.sh
```

For an external launcher, pipe stdout and stderr into files for the same profile:

```bash
your_valheim_server_launch \
  1> >(tee -a "$HOME/valheim-server-status/valheim-logs.d/$(date +%F).MyWorld.stdout.log" \
       | VSS_SERVER_NAME=MyWorld ./vss.log-filter --tail-pipe-input) \
  2> >(tee -a "$HOME/valheim-server-status/valheim-logs.d/$(date +%F).MyWorld.stderr.log" \
       | VSS_SERVER_NAME=MyWorld ./vss.err-filter --tail-pipe-input >&2)
```

Alternatively, configure the existing server's log path in `.env.MyWorld` and use the profile's pipe service. Logs must be readable by the user running that service.

## Discord

Configure each profile's webhook URL and message IDs in the Discord menu for that profile. To create the initial status messages, select the profile in `./setup` and choose the force-update action, or run:

```bash
VSS_SERVER_NAME=MyWorld ./discord/update
```

Cron updates are managed per profile. Webhook URLs and message IDs are stored in the corresponding `.env.<world-name>` file.

The update order is connection information, server status, then recent logs. To enable automatic updates, set `CRONTABWEBHOOKFREQ` in the selected profile to a positive number of minutes; set it to `0` to disable that profile's scheduled update.

## Initial Discord setup

1. Create a webhook in the desired Discord channel and copy its URL.
2. Run `./setup <world-name>` and configure the webhook in that profile's Discord menu.
3. Force an update once to create the connection, status, and logs messages.
4. Copy the message IDs into that profile if you want VSS to update those messages instead of creating new ones.

If a message is deleted, VSS can create a replacement and reports the event in `crash.log`.

## Services and HTTP status

`./setup` generates profile-specific systemd units from the templates in `examples/`, including:

- `valheim-server.<world-name>.service`
- `vss.pipe.<world-name>.service`
- `vss.http.<world-name>.service`

Generated unit files are kept in `systemd/` and linked into `/etc/systemd/system/`. Use `./setup <world-name>` to manage a specific profile's services. Each HTTP profile must use a distinct port.

## Required tools

Install the usual Linux utilities with your package manager when needed, for example:

```bash
sudo apt install coreutils grep procps psmisc sed gawk util-linux curl dnsutils logrotate ncat
```

Valheim dedicated server files and SteamCMD must be installed separately. The optional HTTP status endpoint requires `ncat`; Discord webhooks require `curl`.

## Data isolation

VSS state files in `data/` are suffixed with the world name, including the online and offline player lists, SteamID map, and last-world-save timestamp. Webhook settings, launcher arguments, services, ports, cron jobs, and log file names are also profile-specific.

## Tests

Run the shell regression tests from the repository root:

```bash
for test in tests/test_*.sh; do bash "$test" || exit 1; done
```

The longer `debug_logfilter_pipeline_output*.sh` scripts exercise log parsing and write to the test environment.

## Troubleshooting

- Check `crash.log` for runtime warnings and errors.
- Confirm each profile has a distinct world name and ports.
- Check that the selected profile's log filter is receiving its server output.
- Use `systemctl status <unit-name>` with the profile-specific unit name.
- Ensure that the world name in `.env.<world-name>` matches the profile filename.
