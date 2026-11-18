# Version 3 Plan — Multi-Server Management

## Goal

Allow multiple Valheim servers to be managed from a single VSS installation with shared scripts, while keeping their configuration, monitoring, services, and notifications isolated. Version 3 is a major release: the classic `.env` file will no longer be used as an active configuration.

## Implementation status

The current implementation is an initial multi-server release, not completion of every item in this plan.

- **Implemented:** per-world `.env.<world-name>` profiles, profile-specific launcher arguments and VSS state, shared saves/admin lists, world-qualified logs with shared logrotate, profile-specific service templates, Discord settings, profile-tagged cron updates, optional R2Modman code display in Discord and server status for BepInEx profiles, a separate backed-up V2-to-V3 migration command, a Bash setup dashboard/profile picker, direct start/stop/restart/status/Discord-update/firewall-check commands, cross-profile port collision checks, and an informational UFW rules check.
- **Still outstanding:** a controlled profile/world rename, consistent confirmations for destructive operations, automated post-migration health verification before offering legacy-unit cleanup, a complete interactive rollback procedure, and an isolated BepInEx injection/runtime architecture for profiles sharing one Valheim installation. The migrator stops/disables V2 units and retains their files; it does not verify service health or remove legacy units automatically.

## Agreed conventions

- The world name set by `VHSERVERWORLD` is the server identifier.
- Each server's configuration is `.env.<world-name>`, created from `.env.dist`.
- Optional launcher arguments are stored in `launcher/launcher-args.<world-name>`.
- Scripts and libraries are shared by all servers.
- The contents of `savedir` remain shared. Valheim distinguishes world saves by world name; `adminlist.txt`, `bannedlist.txt`, and `permittedlist.txt` will also be shared across servers.
- World names must be unique. Setup must validate or escape names used in paths and systemd unit names without silently changing them.
- `VHSERVERSEED` is informational only; VSS displays it but cannot set or change the world's seed.

## 1. Configuration and server selection

1. Add a common mechanism to explicitly load the selected server's configuration, for example using a `VSS_SERVER_NAME` identifier.
2. Make `./setup`, status scripts, the log filter, launcher, Discord, HTTP, and their child processes use this mechanism.
3. Remove implicit `.env` loading. Commands run outside setup must receive or explicitly request a server name.
4. Keep `.env.dist` as a configuration template, not as an active server profile.
5. When creating a profile, verify that its name matches `VHSERVERWORLD`, does not already exist, and can be used in generated filenames and service names.

## 2. Launcher arguments and VSS state

1. Make each profile's launcher load `launcher/launcher-args.<world-name>`.
2. Suffix VSS state files in `data/` with the world name, including:
   - `online-players.<world-name>`
   - `offline-players.<world-name>`
   - `steamid-player-map.<world-name>`
   - `last-world-save.<world-name>`
3. Derive these paths from the VSS root and profile name; they are fixed under `data/` and are not configurable in `.env.<world-name>`.
4. Keep `savedir` shared and do not suffix the game's save files. Document that the administration lists in that directory are shared as well.

## 3. Logs and shared log rotation

1. Use a common filename convention:
   - `<date>.<world-name>.stdout.log`
   - `<date>.<world-name>.stderr.log`
2. Update the launcher, pipe, and log filter to write and read these files without mixing servers.
3. Keep logs in a location covered by one logrotate configuration shared by all servers.
4. Generate and install this shared configuration only once. Removing a profile must not remove it while other profiles still use it; removing it must be a separate global operation.
5. Verify that the rotation rule covers files with both extensions.

## 4. systemd services and generated files

For each profile, `./setup` must generate separate units from templates in `examples/`, for example:

- `valheim-server.<world-name>.service`
- `vss.pipe.<world-name>.service`
- `vss.http.<world-name>.service`

Generated files in `systemd/` and files installed in `/etc/systemd/system/` must retain these profile-specific names. Each unit must pass the selected profile to its scripts and use that server's configured paths, ports, launcher, and service user.

Setup must replace every required placeholder in the templates, including those in the Valheim, HTTP, and pipe service examples. Before installation, it must verify that no placeholder remains unresolved. Installing, reinstalling, starting, stopping, or uninstalling a service must affect only the selected profile.

## 5. Discord notifications and scheduled tasks

1. Keep each `.env.<world-name>`'s webhook URL, message IDs, language, and send options independent.
2. Pass the selected profile to Discord scripts called by the log filter, services, and setup.
3. Manage cron jobs per profile so each update uses the correct webhook and state files.
4. Ensure that operating on one profile does not remove or modify other profiles' cron jobs.
5. When BepInEx is enabled, optionally display the profile's manually configured `R2MODMANCODE` in Discord and server status. VSS does not generate or synchronize the mod manager profile.

## 6. `./setup` terminal interface

Modernize the terminal interface in `./setup` to present profiles and available operations clearly, without turning the project into a web interface or duplicating business logic.

The target interface must allow users to:

- list and select a server, showing the status of its services;
- create a profile from `.env.dist` and create its `launcher-args.<world-name>` file;
- edit its configuration, logs, and webhook;
- install, reinstall, start, stop, and remove its services;
- manage its cron jobs and profile-specific maintenance tasks;
- clearly identify global operations, especially management of shared log rotation;
- confirm destructive operations.

The current first-pass implementation provides a Bash dashboard and profile picker, displays the selected profile, world, Valheim process state, ports, and service-unit presence, and groups operations in menus. Direct one-line actions currently available are:

- `./setup --start-server <world-name>`
- `./setup --stop-server <world-name>`
- `./setup --restart-server <world-name>`
- `./setup --status-server <world-name>`
- `./setup --check-firewall <world-name>`
- `./setup --discord-update <world-name>`

Setup rejects overlapping game port ranges and HTTP ports across profiles. The firewall check reports whether UFW has ALLOW rules for the profile's Valheim port range (TCP/UDP) and HTTP status port (TCP); it does not change firewall rules. Missing, inactive, or unavailable UFW is reported without automatically opening ports.

The interface does not yet consistently confirm destructive operations; compare the implementation against the full target list above when continuing the UI work.

## 7. Renaming a world/profile

Since the world name is also the profile identifier, changing it requires renaming or regenerating the associated `.env.<name>`, `launcher-args.<name>`, files in `data/`, systemd units, and cron jobs. Add a controlled rename operation to `./setup` that checks for conflicts, updates references, and does not remove the old profile until the operation has been verified as successful.

**Implementation status:** No controlled rename operation exists yet. The ordinary setup prompt prevents changing `VHSERVERWORLD`; users must not rename profile files manually while services or cron jobs are active.

## 8. Migration from the previous version

Provide an explicit, safe migration procedure to version 3:

1. Read the old `.env` and use `VHSERVERWORLD` as the initial profile name.
2. Create `.env.<world-name>` and `launcher/launcher-args.<world-name>` without overwriting an existing profile.
3. Rename or copy existing VSS state files to their suffixed names while preserving their contents.
4. Generate the profile-specific services from templates and install the shared logrotate configuration.
5. Verify generated files and server status before offering to remove the old units.
6. Document backups, conflicts, and rollback steps.

**Implementation status:** V2 migration is a separate `./migrate-v2-to-v3` command; `./setup` refuses to proceed while a legacy `.env` is present and points the user to the migrator. The migrator creates a restricted backup, stops/disables existing V2 units, migrates the profile/launcher/state files, replaces legacy webhook cron entries, installs shared logrotate and profile-specific units, checks UFW rules without changing them, and asks before enabling/starting V3 units. It does not check V3 service health before asking to start them, nor does it remove legacy units; users must verify the V3 services and remove the stopped V2 units manually. Old logs are not moved. On a partial failure, recovery from the retained backup is manual.

After migration, no script must depend on `.env` as an active configuration.

## 9. Verification and acceptance criteria

- Two profiles can run simultaneously without sharing state files, Discord configuration, launcher arguments, or services.
- Each service and cron job targets the correct profile.
- Game saves remain in the shared `savedir`; world names are unique and administration lists are shared.
- Logs follow the naming convention and one logrotate configuration covers all servers.
- Generated systemd files use the world-name suffix, contain the selected profile's values, and have no unresolved placeholders.
- Managing or removing a profile does not affect other profiles' resources or shared log rotation that is still in use.
- Migration preserves existing data and does not implicitly reactivate the old `.env`.
- Profile validation detects overlapping Valheim ranges and HTTP port collisions. The optional UFW check reports missing required ALLOW rules and never edits firewall configuration.
- An enabled BepInEx profile can publish its configured R2Modman code in Discord and server status; with BepInEx disabled, the code is omitted.
- BepInEx logs and plugin configuration remain isolated per profile even when the Valheim installation is shared; each profile uses the VSS-managed, versioned `BepInEx.cfg`, whose upgrades retain upstream options and can be rolled back.
- Tests use temporary configuration/state/log locations, clean up via traps, leave active server files and `crash.log` unchanged, and pass repeatedly without residue.
- Existing tests are updated for explicit profile loading, and regression tests cover isolation between two servers.

## 10. BepInEx runtime and upgrades

### Confirmed runtime behavior

These findings were checked against the BepInEx source tag `v5.4.23.5`, matching the version embedded by VSS.

- The launcher enables Doorstop per server process with `DOORSTOP_ENABLED=1`, `LD_PRELOAD=libdoorstop.so`, and `DOORSTOP_TARGET_ASSEMBLY`. Disabling BepInEx means not setting the Doorstop preload variables for that process; this is not a single system-wide injector.
- The preloader passes the target assembly path to BepInEx as `DOORSTOP_INVOKE_DLL_PATH`. BepInEx derives `BepInExRootPath` from that path (two parent directories above `BepInEx.Preloader.dll`) and derives `ConfigPath`, `PluginPath`, `PatcherPluginPath`, `CachePath`, the core assembly directory, and `LogOutput.log` from that root.
- The running game's executable path is passed separately. Therefore, a profile-specific BepInEx root can be outside the shared Valheim installation; duplicating the Valheim server binaries is not inherently required.
- `DOORSTOP_MANAGED_FOLDER_DIR` identifies the game's `Managed` directory; it is not the BepInEx root override.
- `BepInEx.cfg` controls logging behavior such as enabling disk logging, append mode, and log levels, but does not choose the log path. The path is rooted at `BepInExRootPath`.

### Target V3 architecture

1. Keep the Valheim installation and server executable shared where desired, but give each profile a distinct writable BepInEx root, such as `bepinex/profiles/<world-name>/BepInEx/`.
2. Set each profile's `VSSBEPINEXDIR` to its root. Set `DOORSTOP_TARGET_ASSEMBLY` to `<profile-root>/BepInEx/core/BepInEx.Preloader.dll`; point `VSSBEPINEXLOGOUTPUT` to `<profile-root>/BepInEx/LogOutput.log`. `LD_PRELOAD` can still load shared, immutable Doorstop native libraries into each separate server process.
3. Keep plugin configuration, `plugins/`, `patchers/`, cache, and logs in the profile root. Each profile's `config/BepInEx.cfg` may link to the VSS-managed, versioned BepInEx configuration; plugin-specific config files remain profile-local.
4. Share only immutable package files where safe (for example, versioned core assemblies and Doorstop libraries). Do not point all profiles at one writable `BepInEx` directory or one `LogOutput.log`. Validate that any links to shared files preserve the profile-specific target path used to derive `BepInExRootPath`.
5. Update `install_bepinex.sh` and `remove_bepinex.sh` for this layout. Track links created by VSS; rollback must remove only those links, including broken ones, without deleting pre-existing files or another profile's setup.
6. Add a root-level `./bepinex_upgrade.sh` workflow for upgrading a pinned official BepInEx package, applying VSS-required settings to each profile's `BepInEx.cfg` without discarding options introduced by newer versions, and retaining the previous package for rollback.

### BepInEx acceptance tests

- Start two server processes against the same Valheim installation with different BepInEx roots. Verify each loads only its profile's plugins/configuration and writes a separate `LogOutput.log`.
- Verify that the VSS pipe for each profile reads only that profile's BepInEx log and that connect/disconnect events update only that profile's player state.
- Verify enabling or removing BepInEx for one profile does not change another profile's target assembly, links, plugins, or logs.
- Verify rollback removes VSS-created links (including broken ones) and preserves pre-existing files in the server directory.
- Verify an upgrade preserves newly introduced upstream configuration options, applies VSS-required logging settings, and can restore the prior package and profile configuration.
