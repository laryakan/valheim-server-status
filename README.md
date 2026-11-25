# Valheim Server Status

VSS is a lightweight Bash-based monitoring and status tool for Valheim dedicated servers. One VSS checkout can manage multiple servers using shared scripts and a separate configuration profile for each world.

## Requirements

- Linux and Bash
- `systemctl` for system services
- `sudo` for systemd service management and the shared Valheim maintenance update
- SteamCMD for the explicit shared-server update workflow
- `dig` (`dnsutils`/`bind-tools`) for the default public-IP lookup; `PUBLICIP` can also be set manually
- `curl` for Discord webhooks
- `ncat` for the optional HTTP status endpoint and the BepInEx upgrade integration test
- `logrotate` for rotating VSS logs
- `wget`, `unzip`, and `awk` to download BepInEx on first activation when no active image exists, or to run `./bepinex_upgrade.sh`
- `base64` (GNU coreutils) to run the BepInEx upgrade integration test

## Server profiles

Each server is identified by its Valheim world name (`VHSERVERWORLD`) and has a configuration file named `.env.<world-name>`. The root `.env` stores shared installation settings; `.env.server.dist` is the template used to create profiles, and `.env.common.dist` is its shared-settings template. `./setup` creates the shared `.env` on first profile load and synchronizes newly added template keys without overwriting existing values. `VSSDIR` is the shared installation root, derived from the location of `.env`.

Server paths (`VHSERVERDIR`, `VHSERVERSAVEDIR`), service user, shared log directory, VSS tools, public IP, webhook URL, and Discord send/cron options belong to the common `.env`. Each profile uses one webhook message ID, `STATUSMESSAGEID`, for status, connection details, and optional recent logs. Existing profiles may still contain `LASTLOGMESSAGEID` or `SERVERCONNECTIONINFOMESSAGEID`; if `STATUSMESSAGEID` is empty, the updater reuses one of those older IDs rather than creating a second message.

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
`--check-firewall` checks whether active UFW has ALLOW rules for the profile's Valheim port pair (`VHSERVERPORT` and `VHSERVERPORT+1`, TCP and UDP) and HTTP status port (TCP). It is informational only: it never adds or changes firewall rules, and reports when UFW is inactive, unavailable, or missing rules.

Valheim updates are explicit because all profiles share the same server files. Do not enable the commented `ExecStartPre` update in the service template. Run:

```bash
./setup --maintenance-update
# Or select a Steam branch for this update:
./setup --maintenance-update public
```

The command stops every installed profile's Valheim service, refreshes each configured Discord status message to reflect the stopped service, runs SteamCMD once against the shared `VHSERVERDIR`, then starts only the services that were active before the request, sequentially. A Discord refresh is skipped if the webhook or a valid message ID is missing; a failed refresh or 15-second timeout is reported without preventing maintenance or restarts. After restart, the normal profile Discord cron updates the message; if that job is disabled, update it manually. Services that were already stopped remain stopped. `vss.maintenance` checks connected-player state across all profiles, sends one warning when needed, then calls the same operation. The warning title and description use the shared `VSS_LANG` setting (`en` or `fr`). Setup can schedule it as one global job; do not schedule it separately per profile.

The branch is passed to SteamCMD as `-beta <branch>` ([SteamCMD documentation](https://developer.valvesoftware.com/wiki/SteamCMD)). Without an argument, setup uses `VSSSTEAMBRANCH` from the shared `.env`, including for scheduled maintenance. New installations and existing shared configurations missing this setting default to `default_old` (the previous stable release); set it to `public` for the current stable release. An argument overrides the setting for that update only.

Accepted names are `public`, `default_old`, `default_pre1_0`, `default_preml`, `default_precta`, `default_prebw`, `default_preal`, and `public-test`. Invalid names stop maintenance before services are stopped. This list must be updated if Valve changes the available branches. The command does not support `-betapassword` for password-protected branches such as `public-test`.

**Back up your worlds before changing branches**, especially when reverting to an older version. The branch affects the shared server installation and every profile; clients must use a compatible version.

Schedule or remove the global planned maintenance job from setup:

```bash
./setup --schedule-maintenance
./setup --remove-maintenance-schedule
```

Scheduling adds one idempotent entry to root's crontab for daily 05:00 system-local time. It requires `sudo`; if an older manual `vss.maintenance` cron entry exists, remove it first to avoid duplicate updates. The scheduled job checks every profile for connected players, then performs one global update.

Setup also rejects overlapping Valheim port ranges and HTTP ports across profiles. HTTP ports must not overlap any profile's Valheim range.

Valheim's dedicated-server guide describes the default port pair as `2456-2457`: the configured port and the next port. For a server not using crossplay, configure router port forwarding to match the server's ports. With the `-crossplay` argument, router forwarding is not required; the port still distinguishes servers sharing a public IP address. VSS checks conflicts and UFW rules for `VHSERVERPORT` and `VHSERVERPORT+1`; new profiles are assigned the next unused two-port pair. See the [official dedicated-server guide](https://valheim.com/support/a-guide-to-dedicated-servers/).

The profile selector and **Switch server profile** menu show a compact overview card for every profile, including its server display name, online/starting/offline state, game port, BepInEx setting, informational seed, connected-player count when state is available, shared Discord webhook configuration, and whether that profile's automatic update job is scheduled, missing, or disabled. Webhook status means the URL is configured locally; it does not test Discord connectivity. Player counts come from VSS's parsed log state, not a live game query, so they can be stale if log processing has stopped. The selected profile is marked. The main menu shows the same Discord indicators for the currently selected profile. Menus are grouped by configuration, monitoring, BepInEx/modding, and maintenance; BepInEx activation, deactivation, and the optional mod-manager share code are configured together. In a terminal, use the up/down arrows and Enter to navigate. The currently selected action is highlighted, and typing its displayed number remains available as a shortcut. The profile picker also accepts a profile number or name, `n` to create one, or `q` to quit. It uses only Bash and standard terminal output (no additional TUI package). Colors are disabled with `NO_COLOR`, and the screen is only cleared in an interactive terminal.

The BepInEx indicator is red when disabled, green when enabled with a valid shared configuration link, and yellow with a warning label when enabled but that link is invalid. Use `./setup --check-bepinex-config` for details.

World names used as profile IDs must start with a letter or number, contain only letters, numbers, dots, underscores, and hyphens, must not contain `..`, and must be unique. Profile/world IDs cannot currently be renamed in setup. Valheim saves are stored in the shared `savedir` and distinguished by world name. The game's `adminlist.txt`, `bannedlist.txt`, and `permittedlist.txt` files are shared by all profiles.

The setup menu can reset the selected world by deleting its matching `.fwl` and `.db` save files. It requires the exact confirmation `DELETE WORLD`, stops and restarts the server only if its managed systemd service was running, and refuses to proceed if the server is running outside that service. This is destructive; preserve a separate world backup if needed.

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
2. Splits the old `.env` into the shared root `.env` and `.env.<world-name>`, and renames launcher arguments and VSS state files to profile-specific names. It backs up all four configured legacy state files, including files outside `data/`, and aborts rather than overwriting existing profile/state targets.
3. Removes cron lines containing the legacy `WEBHOOKUPDATE` path, preserves unrelated cron entries, and installs the profile-tagged V3 Discord update if its configured frequency is positive.
4. Installs the shared V3 logrotate configuration and removes the old `/etc/logrotate.d/valheim` rule after backing it up.
5. Installs the V3 server unit and corresponding pipe/HTTP units when those V2 units existed. Legacy unit files are retained but left stopped and disabled. `STATUSPORT` is validated only when the legacy `vss.http.service` unit exists; otherwise HTTP port validation and its UFW rule check are skipped. The unused value is preserved; set a valid port before installing HTTP later.
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

For an external server not launched by VSS, you can instead configure its existing log path in `.env.MyWorld` and use the profile's standalone pipe service. Logs must be readable by the service user. This pipe service is not needed for a vanilla server managed by VSS: the vanilla launcher sends stdout directly to `vss.log-filter`.

## Discord

All profiles use one shared Discord webhook URL and shared send options; separate webhook URLs per profile are not supported. Each profile has one message containing its server identity and status, optional connection details, and optional recent logs. To create the initial message, select each profile in `./setup` and choose **Send an update for this profile now**, or run:

```bash
VSS_SERVER_NAME=MyWorld ./discord/update
```

Cron jobs for Discord updates are generated per profile, but their frequency and webhook URL are shared. Updating the shared cron frequency refreshes all configured profile jobs; removing one profile removes only its job. The webhook URL and options live in the root `.env`; `STATUSMESSAGEID` lives in each `.env.<world-name>`.

Set the shared `SENDSERVERCONNECTIONINFO` to `1` to include connection details in the profile status message. Set `SENDLASTLOGS` to a positive number to include that many recent log lines in the same message. Set the shared `CRONTABWEBHOOKFREQ` to a positive number of minutes to enable updates for all profiles; set it to `0` to disable all profile update jobs. Older separate connection/log messages are not deleted automatically; remove those manually after confirming the combined message works.

For modded servers, set `VSSBEPINEXENABLED=1` and configure the profile's R2Modman/Thunderstore UUID share code in the BepInEx setup menu or directly:

```bash
./setup --set-r2modman-code MyWorld 01a1eaf3-9be3-9083-b9b4-26768368368e
./setup --set-r2modman-code MyWorld '' # Clear the code
```

The command sets `R2MODMANCODE` for the named profile and performs normal setup configuration synchronization; it does not send a Discord update or restart the server. The code is shown in Discord and the server status output (including the HTTP status endpoint), including while the server is offline. It is omitted when BepInEx is disabled or no code is configured. VSS does not generate or synchronize the mod profile; maintain the share code from the mod manager.

Each profile has its own BepInEx root under `bepinex/profiles/<world-name>/`. Plugins, plugin configuration, patchers, cache, and `LogOutput.log` are profile-local. `BepInEx/core` is a real per-profile directory whose shared files are symlinked to `bepinex/current`; the root-level `libdoorstop.so` and `BepInEx.cfg` are also file symlinks to the current shared image. External mod synchronization must preserve or restore the `BepInEx.cfg` link rather than replace it with a profile-local file. The Valheim server files are not populated with shared BepInEx links.

Run `./setup --check-bepinex-config` to check the configuration link of every profile without modifying files. It reports disabled profiles without a configuration as skipped and returns a nonzero status for missing, incorrect or broken links, unreadable profiles, or no profiles. The link must point directly to `bepinex/current/BepInEx/config/BepInEx.cfg` in the installation.

To restore a profile's link, stop its server and run `./setup --recreate-bepinex-config-link MyWorld`. The command replaces an existing profile-local `BepInEx.cfg` file or incorrect link, so back up any local settings first. It requires the shared configuration and existing profile directories, does not restart the server, and leaves other profiles unchanged.

The vanilla launcher sends stdout directly to `vss.log-filter`; it does not need `vss.pipe`. Choose **Enable packaged BepInEx** to stop a running managed server, prepare the profile, install/start its `vss.pipe.<world-name>.service`, and restart the server with BepInEx. If `bepinex/current` is missing or broken, setup downloads the latest official BepInEx release through `bepinex_upgrade.sh`, creates the versioned image and `current` symlink, then prepares the enabled profiles. This first download requires network access plus `wget`, `unzip`, and `awk`. The pipe reads that profile's `LogOutput.log`. Disabling BepInEx stops a running managed server and removes Doorstop links; it also removes the pipe if BepInEx setup created it. A pipe that was already installed before activation is kept for externally redirected logs. Setup then restarts a previously running server in vanilla mode; a stopped server remains stopped. The profile's plugins and configuration are retained. Setup refuses to switch a server that is running outside its managed systemd unit. Re-selecting Enable when BepInEx is already enabled also repairs a missing image; it does not restart Valheim when setup succeeds.

Upgrade the shared BepInEx Linux x64 image to the latest official release with:

```bash
./setup --upgrade-bepinex
# Equivalent direct invocation:
./bepinex_upgrade.sh
```

The setup command is a direct shortcut to the same script and does not stop or restart servers. Stop affected servers before upgrading.

After switching the shared image, the upgrade restores the shared `BepInEx.cfg` link for every enabled profile, replacing any existing profile-local file or incorrect link without a backup. Back up local settings first. Disabled profiles are not changed. If post-switch synchronization fails, image rollback is attempted, but already replaced profile configurations are not restored.

The script requires `wget` and `unzip`. It downloads and extracts a versioned image under `bepinex/`, enforces VSS's BepInEx logging settings while preserving other upstream `BepInEx.cfg` options, prepares enabled profiles, and atomically creates or switches `bepinex/current`. A profile's detected BepInEx version and update date change when the log filter detects a different version, typically after a restart; the upgrade command itself does not update them. If the archive omits `BepInEx.cfg`, the script creates a minimal configuration containing VSS's required logging settings; BepInEx fills in its other defaults on first launch. On the first isolated upgrade, legacy plugin files in the active image's `BepInEx/plugins` and plugin configuration files in `BepInEx/config` are copied into every enabled profile; `BepInEx.cfg` remains shared. Logs, cache, and patchers are not migrated. After a successful switch, the previously active image is removed. A failure before switching leaves the current link and old image untouched. If profile synchronization fails after switching, the script attempts to restore the previous link and re-synchronize profiles; it retains the old image, but filesystem failures can prevent complete rollback. If shared plugin/configuration files exist but no profile is enabled, the upgrade stops rather than discard them. For an offline test fixture, set `BEPINEX_RELEASES_LATEST_URL` to a local HTTP JSON fixture whose Linux x64 asset URL points to a local ZIP fixture. The integration test uses `ncat` and the system `base64` utility to serve and decode committed fixtures; it does not require Python.

`VHSERVERSEED` is informational: VSS displays it in status/Discord but does not pass it to Valheim to set or change world generation.

This project has no staging server, and the BepInEx runtime test uses a stub server rather than real plugin loading. Before upgrading production, back up the active BepInEx image and `bepinex/profiles/`; verify a low-impact profile during a maintenance window. The upgrade removes the previous active image after success, and failed profile preparation can leave files or links to inspect before retrying.

## Initial Discord setup

1. Create a webhook in the desired Discord channel and copy its URL.
2. Run `./setup <world-name>` and configure the shared webhook URL in the Discord menu.
3. Force an update once to create the combined profile message.
4. Copy that message's ID into `STATUSMESSAGEID` if you want VSS to update it instead of creating a new one.

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

VSS state files are fixed under the installation's `data/` directory and suffixed with the world name: online and offline player lists, SteamID map, and last-world-save timestamp. Their paths are derived by VSS and are not configurable in profile `.env` files. If an existing profile has a state file at a custom path, move it to the fixed `data/` path shown by the loader error before starting that profile. Message IDs, launcher arguments, services, ports, VSS state, and log file names are profile-specific. Discord webhook credentials/options and update frequency are shared; cron entries are generated per profile.

The log filter records the last `Opened Steam server` or `Opened PlayFab server` timestamp in the profile's `VALSERVERLASTOPEN`. Setup, Discord and HTTP report **offline** when the profile's systemd service is stopped or missing, **starting** while it is active but no opening has been recorded since its activation, and **online** once an opening has been recorded. Starting has no timeout. If systemd or the activation time cannot be inspected, the status is **offline** and a diagnostic is emitted. Timestamps have one-second precision; if the filter misses an opening line, the status can remain starting.

The filter dates openings, Valheim and BepInEx version changes, and completed world saves using the server's local time when it processes the line, not the timestamp in the log. Version and save dates use `DD/MM/YYYY HH:MM:SS`; opening dates use `YYYY-MM-DD HH:MM:SS` internally to avoid ambiguity with older `MM/DD/YYYY` opening records. Existing version and save dates are not rewritten; status displays convert valid, unambiguously US-formatted dates (such as `11/25/2026`), but leave ambiguous dates (such as `05/06/2026`) unchanged. Version dates change only when the detected version changes. An unknown date remains unknown if the recorded version is unchanged. Lines written by the filter to VSS logs are prefixed with their local capture time; the known Unity timestamp immediately after a BepInEx Unity Log prefix or at the beginning of a vanilla log line is removed to avoid duplicate timestamps. Other dates in messages remain unchanged. If the clock cannot be read, the original line is preserved and an error is reported. The external-server pipe does not rewrite its input logs or create duplicate entries; existing logs are not modified retroactively. Replaying an old opening line can incorrectly make an active server appear online. The standalone pipe starts following at the end of the file and does not replay existing lines.

## Tests

Run the shell regression and log-pipeline tests from the repository root:

```bash
for test in tests/test_*.sh tests/debug_logfilter_pipeline_output*.sh; do
  bash "$test" || exit 1
done
```

Tests that exercise log parsing and profile state use temporary files and clean them up on exit. The setup UI test uses the standard `script` utility (from util-linux) to exercise arrow-key navigation in a pseudo-terminal. Setup tests also cover profile switching, BepInEx pipe ownership, world-reset safeguards, and service-removal failures. The BepInEx runtime test launches two modded profiles and one vanilla profile concurrently against a stub server to verify environment isolation. Re-running the suite should not modify active profile configuration, server data, production logs, or `crash.log`; review any new test's side effects before adding it.

## Troubleshooting

- Check `crash.log` for runtime warnings and errors.
- Confirm each profile has a distinct world name and ports.
- Check that the selected profile's log filter is receiving its server output.
- Use `systemctl status <unit-name>` with the profile-specific unit name.
- Ensure that the world name in `.env.<world-name>` matches the profile filename.
