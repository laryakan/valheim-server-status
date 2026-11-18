# Version 3 Plan — Multi-Server Management

## Goal

Allow multiple Valheim servers to be managed from a single VSS installation with shared scripts, while keeping their configuration, monitoring, services, and notifications isolated. Version 3 is a major release: the classic `.env` file will no longer be used as an active configuration.

## Agreed conventions

- The world name set by `VHSERVERWORLD` is the server identifier.
- Each server's configuration is `.env.<world-name>`, created from `.env.dist`.
- Optional launcher arguments are stored in `launcher/launcher-args.<world-name>`.
- Scripts and libraries are shared by all servers.
- The contents of `savedir` remain shared. Valheim distinguishes world saves by world name; `adminlist.txt`, `bannedlist.txt`, and `permittedlist.txt` will also be shared across servers.
- World names must be unique. Setup must validate or escape names used in paths and systemd unit names without silently changing them.

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
3. Set the corresponding paths in each `.env.<world-name>`.
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

## 6. `./setup` terminal interface

Modernize the terminal interface in `./setup` to present profiles and available operations clearly, without turning the project into a web interface or duplicating business logic.

The interface must allow users to:

- list and select a server, showing the status of its services;
- create a profile from `.env.dist` and create its `launcher-args.<world-name>` file;
- edit its configuration, logs, and webhook;
- install, reinstall, start, stop, and remove its services;
- manage its cron jobs and profile-specific maintenance tasks;
- clearly identify global operations, especially management of shared log rotation;
- confirm destructive operations.

## 7. Renaming a world/profile

Since the world name is also the profile identifier, changing it requires renaming or regenerating the associated `.env.<name>`, `launcher-args.<name>`, files in `data/`, systemd units, and cron jobs. Add a controlled rename operation to `./setup` that checks for conflicts, updates references, and does not remove the old profile until the operation has been verified as successful.

## 8. Migration from the previous version

Provide an explicit migration procedure to version 3:

1. Read the old `.env` and use `VHSERVERWORLD` as the initial profile name.
2. Create `.env.<world-name>` and `launcher-args.<world-name>` without overwriting an existing profile.
3. Rename or copy existing VSS state files to their suffixed names while preserving their contents.
4. Generate the profile-specific services from templates and install the shared logrotate configuration.
5. Verify generated files and server status before offering to remove the old units.
6. Document backups, conflicts, and rollback steps.

After migration, no script must depend on `.env` as an active configuration.

## 9. Verification and acceptance criteria

- Two profiles can run simultaneously without sharing state files, Discord configuration, launcher arguments, or services.
- Each service and cron job targets the correct profile.
- Game saves remain in the shared `savedir`; world names are unique and administration lists are shared.
- Logs follow the naming convention and one logrotate configuration covers all servers.
- Generated systemd files use the world-name suffix, contain the selected profile's values, and have no unresolved placeholders.
- Managing or removing a profile does not affect other profiles' resources or shared log rotation that is still in use.
- Migration preserves existing data and does not implicitly reactivate the old `.env`.
- Existing tests are updated for explicit profile loading, and regression tests cover isolation between two servers.
