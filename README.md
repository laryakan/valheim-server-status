# Valheim Server Status

VSS is a lightweight Bash-based monitoring and status tool for Valheim dedicated servers. One VSS checkout can manage multiple servers using shared scripts and a separate configuration profile for each world.

## Requirements

- Linux and Bash
- `systemctl` for system services
- `curl` for Discord webhooks
- `ncat` for the optional HTTP status endpoint and the BepInEx upgrade integration test
- `logrotate` for rotating VSS logs
- `wget`, `unzip`, and `awk` to run the optional `./bepinex_upgrade.sh` workflow
- `base64` (GNU coreutils) to run the BepInEx upgrade integration test

## Server profiles

Each server is identified by its Valheim world name (`VHSERVERWORLD`) and has a configuration file named `.env.<world-name>`. The classic `.env` file is no longer an active configuration. `.env.dist` is the template used to create profiles.

Start the setup interface:

```bash
./setup
```

Choose an existing profile or create one by entering its world name. Profiles can also be listed, created, or selected directly:

```bash
./setup --help
./setup --list
./setup --create MyWorld
./setup MyWorld
```

`./setup --create` creates a profile and opens its interactive menu. `./setup <world-name>` selects an existing profile and opens the same menu.

Server actions can run without opening the interactive menu. Lifecycle actions use that profile's systemd unit (and may prompt for `sudo`); Discord updates use its webhook configuration:

```bash
./setup --start-server MyWorld
./setup --stop-server MyWorld
./setup --restart-server MyWorld
./setup --status-server MyWorld
./setup --check-firewall MyWorld
./setup --discord-update MyWorld
```

`--status-server` reports the systemd unit status and returns its status code. These commands require the profile name explicitly; they do not infer it from another profile or from the current directory.
`--check-firewall` checks whether active UFW has ALLOW rules for the profile's Valheim port range (`VHSERVERPORT` through `VHSERVERPORT+2`, TCP and UDP) and HTTP status port (TCP). It is informational only: it never adds or changes firewall rules, and reports when UFW is inactive, unavailable, or missing rules.

Setup also rejects overlapping Valheim port ranges and HTTP ports across profiles. HTTP ports must not overlap any profile's Valheim range.

The interactive setup dashboard shows the selected world, Valheim process state, ports, and installed service units. Menus are grouped by configuration, monitoring, and maintenance; the profile picker accepts a profile name, `n` to create one, or `q` to quit. It uses only Bash and standard terminal output (no additional TUI package). Colors are disabled with `NO_COLOR`, and the screen is only cleared in an interactive terminal.

World names used as profile IDs must start with a letter or number, contain only letters, numbers, dots, underscores, and hyphens, must not contain `..`, and must be unique. Valheim saves are stored in the shared `savedir` and distinguished by world name. The game's `adminlist.txt`, `bannedlist.txt`, and `permittedlist.txt` files are shared by all profiles.

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

Run the dedicated migration command from the VSS checkout; `./setup` no longer performs V2 migration implicitly:

```bash
./migrate-v2-to-v3
```

The script requires the legacy `.env`, a valid `VHSERVERWORLD`, and an existing `VHSERVERDIR`. It asks for confirmation, creates a permission-restricted backup under `migration-backups/`, then:

1. Stops and disables the V2 systemd units it finds (`valheim-server.service`, `vss.pipe.service`, and `vss.http.service`).
2. Renames `.env`, launcher arguments, and VSS state files to the profile-specific names. It backs up all four configured legacy state files, including files outside `data/`, and aborts rather than overwriting existing profile/state targets.
3. Removes cron lines containing the legacy `WEBHOOKUPDATE` path, preserves unrelated cron entries, and installs the profile-tagged V3 Discord update if its configured frequency is positive.
4. Installs the shared V3 logrotate configuration and removes the old `/etc/logrotate.d/valheim` rule after backing it up.
5. Installs the V3 server unit and corresponding pipe/HTTP units when those V2 units existed. Legacy unit files are retained but left stopped and disabled.
6. Checks UFW rules for the migrated profile without changing them; missing rules or an unavailable/inactive UFW are warnings and do not stop migration.
7. Asks for `START` before enabling and starting the V3 units. If declined, the new units remain installed but stopped and disabled.

Review the retained backup and verify systemd status, server logs, Discord updates, cron, and logrotate after migration. Remove the stopped V2 unit files only after successful verification. Existing log files are not moved or renamed. If migration fails partway through, it prints the backup location; restoration is manual, so do not delete the backup until the V3 installation is confirmed.

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

For modded servers, set `VSSBEPINEXENABLED=1` and put the profile's R2Modman/Thunderstore UUID share code (for example `01a1eaf3-9be3-9083-b9b4-26768368368e`) in `R2MODMANCODE` in that world's `.env`. The code is shown in Discord and the server status output (including the HTTP status endpoint), including while the server is offline. It is omitted when BepInEx is disabled or no code is configured. VSS does not generate or synchronize the mod profile; maintain the share code from the mod manager.

Upgrade the shared BepInEx Linux x64 image to the latest official release with:

```bash
./bepinex_upgrade.sh
```

The script requires `wget` and `unzip`. It downloads and extracts a versioned image under `bepinex/`, enforces VSS's BepInEx logging settings while preserving other upstream `BepInEx.cfg` options, then atomically switches `bepinex/current`. Previous image directories are retained for manual rollback; the script does not migrate or modify plugins. For an offline test fixture, set `BEPINEX_RELEASES_LATEST_URL` to a local HTTP JSON fixture whose Linux x64 asset URL points to a local ZIP fixture. The integration test uses `ncat` and the system `base64` utility to serve and decode committed fixtures; it does not require Python.

`VHSERVERSEED` is informational: VSS displays it in status/Discord but does not pass it to Valheim to set or change world generation.

## Initial Discord setup

1. Create a webhook in the desired Discord channel and copy its URL.
2. Run `./setup <world-name>` and configure the webhook in that profile's Discord menu.
3. Force an update once to create the connection, status, and logs messages.
4. Copy the message IDs into that profile if you want VSS to update those messages instead of creating new ones.

If a message is deleted, VSS can create a replacement and reports the event in `crash.log`. `setup` itself does not redirect its diagnostics to `crash.log`; setup errors are shown in the terminal.

## Services and HTTP status

`./setup` generates profile-specific systemd units from the templates in `examples/`, including:

- `valheim-server.<world-name>.service`
- `vss.pipe.<world-name>.service`
- `vss.http.<world-name>.service`

Generated unit files are kept in `systemd/` and linked into `/etc/systemd/system/`. Use `./setup <world-name>` to manage a specific profile's services. Profiles must use distinct Valheim port ranges and HTTP ports, with no HTTP/game port overlap.

## Required tools

Install the usual Linux utilities with your package manager when needed, for example:

```bash
sudo apt install coreutils grep procps psmisc sed gawk util-linux curl dnsutils logrotate ncat
```

Valheim dedicated server files and SteamCMD must be installed separately. The optional HTTP status endpoint requires `ncat`; Discord webhooks require `curl`.
The optional `--check-firewall` command uses `ufw` when available; it only reads rules and never opens ports.

## Data isolation

VSS state files are fixed under the installation's `data/` directory and suffixed with the world name: online and offline player lists, SteamID map, and last-world-save timestamp. Their paths are derived by VSS and are not configurable in profile `.env` files. If an existing profile has a state file at a custom path, move it to the fixed `data/` path shown by the loader error before starting that profile. Webhook settings, launcher arguments, services, ports, cron jobs, and log file names are also profile-specific.

## Tests

Run the shell regression and log-pipeline tests from the repository root:

```bash
for test in tests/test_*.sh tests/debug_logfilter_pipeline_output*.sh; do
  bash "$test" || exit 1
done
```

Tests that exercise log parsing and profile state use temporary files and clean them up on exit. Re-running the suite should not modify active profile configuration, server data, production logs, or `crash.log`; review any new test's side effects before adding it.

## Troubleshooting

- Check `crash.log` for runtime warnings and errors.
- Confirm each profile has a distinct world name and ports.
- Check that the selected profile's log filter is receiving its server output.
- Use `systemctl status <unit-name>` with the profile-specific unit name.
- Ensure that the world name in `.env.<world-name>` matches the profile filename.
