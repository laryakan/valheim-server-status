# Version 3 — Multi-Server Management

## Purpose and status

Version 3 lets one VSS checkout manage multiple Valheim worlds with shared tools and server files, while keeping profile-specific state, services, ports, launcher arguments, and message IDs separate.

This document tracks the current branch implementation and the work that remains. “Implemented” describes behavior present in this branch; it does not imply that an operator has run the migration or enabled every optional feature.

## Implemented features

### Shared and per-profile configuration

- Each server is selected explicitly by `VSS_SERVER_NAME` and has a `.env.<world-name>` file based on `.env.server.dist`.
- The root `.env` contains shared installation configuration based on `.env.common.dist`. `VSSDIR` is the shared installation root.
- `setup` creates shared configuration when needed and synchronizes new template keys into existing configuration without overwriting existing values.
- Shared settings include server and save paths, service user, log directory, VSS tool paths, public IP, webhook credentials/options, language, and Discord update frequency.
- The only profile-specific Discord settings are `STATUSMESSAGEID`, `LASTLOGMESSAGEID`, and `SERVERCONNECTIONINFOMESSAGEID`.
- Profile names are validated and must match `VHSERVERWORLD`. Setup checks game-port range and HTTP-port collisions across profiles.
- Valheim save files and the `adminlist.txt`, `bannedlist.txt`, and `permittedlist.txt` files remain shared. `VHSERVERSEED` is informational; VSS cannot set or change world generation.

### State, logs, launcher, and services

- Each profile has its own `launcher/launcher-args.<world-name>` file.
- VSS state files use world-name suffixes: `online-players`, `offline-players`, `steamid-player-map`, and `last-world-save`. Their paths are fixed under `data/` and are derived by the config loader.
- Server logs use `<date>.<world-name>.stdout.log` and `<date>.<world-name>.stderr.log`. One shared logrotate configuration covers all profiles.
- Setup renders separate `valheim-server.<world-name>.service`, `vss.pipe.<world-name>.service`, and `vss.http.<world-name>.service` units from shared examples. Units pass the selected profile to their scripts.
- Setup includes a Bash dashboard and profile picker, profile creation, per-profile service operations, and direct CLI commands for starting, stopping, restarting, checking status, checking UFW rules, and updating Discord.
- The UFW check is informational only; it does not alter firewall rules.

### Discord and scheduled jobs

- Webhook credentials and send options are shared; each profile retains its own message IDs and state.
- Discord updates are scheduled separately per profile, using shared credentials and the profile-specific message IDs. The shared `CRONTABWEBHOOKFREQ` setting updates or removes all profile jobs; removing a profile removes only that profile's cron entry.
- Existing Discord messages are updated rather than duplicated. Deleted messages can be recreated, and webhook failures are handled without crashing the main monitoring flow.

### Shared Valheim maintenance

- Service startup no longer runs SteamCMD `app_update`; `ExecStartPre` is commented out in the service template to avoid changing shared server files while another instance is running.
- `./setup --maintenance-update` stops every installed Valheim server service, runs SteamCMD once against the shared `VHSERVERDIR`, then starts only the services that were active before the operation, sequentially. Previously stopped services remain stopped. The operation attempts to restore active services even if the update fails.
- `vss.maintenance` checks connected-player state across profiles. If players are connected, it sends one warning and delays five minutes; the warning title and description use shared `VSS_LANG` (`en` or `fr`). It then invokes the same global update path.
- `./setup --schedule-maintenance` installs one idempotent entry in root's crontab for daily 05:00 local time. `./setup --remove-maintenance-schedule` removes it. Do not schedule one maintenance job per profile. Remove any older manual entry to avoid duplicate updates.

### V2-to-V3 migration

- `./migrate-v2-to-v3` is an explicit migration command; setup refuses to treat an unmarked legacy root `.env` as V3 shared configuration.
- The migrator creates a restricted backup, splits legacy settings into shared `.env` and profile `.env.<world-name>`, and migrates launcher arguments and state files without overwriting existing targets.
- It stops and disables legacy V2 systemd units, replaces the legacy Discord cron entry while preserving unrelated entries, installs shared logrotate and profile-specific units, refreshes systemd, checks UFW rules without changing them, and asks before enabling/starting V3 units.
- Legacy units and the backup are retained for manual verification and recovery.

### BepInEx features currently present

- A profile can enable/disable the packaged BepInEx integration through setup. The launcher enables Doorstop for that process and VSS can tail BepInEx logs through the profile's pipe.
- Each profile has a distinct BepInEx root at `bepinex/profiles/<world-name>/`. The preloader target, Doorstop library path, plugin directory, plugin configuration, cache, and `LogOutput.log` use that profile's paths.
- Shared core and Doorstop files are linked file-by-file into real per-profile directories. `BepInEx/config/BepInEx.cfg` is the only shared configuration file and links to `bepinex/current/BepInEx/config/BepInEx.cfg`.
- BepInEx 5.4.23.5 derives its root from `Path.GetFullPath(DOORSTOP_INVOKE_DLL_PATH)` and then resolves config, plugins, cache, and disk logs from that root. The launcher uses the profile's `DOORSTOP_TARGET_ASSEMBLY`; file-level links keep the target path profile-specific.
- Setup prepares the profile and installs/starts its `vss.pipe.<world-name>.service` when BepInEx is enabled. Disabling BepInEx removes Doorstop injection and BepInEx library search paths on the next launch, retains that profile's data, and restarts an installed pipe to read standard server logs.
- `R2MODMANCODE` is validated and can be displayed in Discord and server status while BepInEx is enabled.
- `./bepinex_upgrade.sh` downloads the latest official Linux x64 package, validates and extracts it into a versioned directory, enforces VSS logging values in `BepInEx.cfg` while retaining other upstream settings, and atomically switches `bepinex/current`. On the first isolated upgrade, it copies only the active image's plugins and plugin configs to all enabled profiles, keeps `BepInEx.cfg` shared, does not migrate logs, cache, or patchers, and removes the previously active image after success.

## Remaining work

### 1. Validate isolated BepInEx in production

- The runtime regression test launches two enabled profiles and one vanilla profile concurrently against a stub server to verify process environment isolation; it does not validate real plugin loading.
- Start two enabled profiles concurrently and confirm each loads only its own plugins/configuration and writes its own `LogOutput.log`.
- Confirm each profile's pipe updates only that profile's VSS state.
- Verify upgrade and recovery procedures against a production-like copy before updating production; the active previous image is removed after a successful upgrade.
- Confirm that disabling/re-enabling one profile preserves its data and does not alter another profile's BepInEx root.

### 2. Profile rename

Add a controlled rename operation that checks conflicts and updates the profile file, launcher arguments, state paths, service units, and cron entry. Do not remove the old profile until the new configuration has been verified.

### 3. Migration verification and rollback

- Add post-start health checks before declaring migration successful.
- Provide a guided rollback procedure; recovery from the retained migration backup is currently manual.
- Offer safe cleanup of stopped legacy units only after V3 services have been verified. The current migrator intentionally retains them.

### 4. Setup confirmations and lifecycle edges

- Review destructive setup operations for consistent, explicit confirmation.
- Verify maintenance behavior for stop failures, SteamCMD failures, restart failures, and interrupted operations. Normal update failures restore the previously active services; full guided recovery remains outstanding.
- Review the global maintenance schedule against any pre-existing manually managed cron entries before enabling it in production.

## Validation and operational dependencies

- Runtime target: Bash on Linux with systemd. Service management and the root maintenance schedule require `sudo`; the update workflow also requires SteamCMD.
- `curl` is used for Discord webhooks. `dig` supplies the default public IP but can be replaced by a configured `PUBLICIP`. `ncat` is used by the optional HTTP endpoint and the BepInEx integration test.
- `./bepinex_upgrade.sh` requires `wget`, `unzip`, and `awk`; its integration test also uses `ncat` and `base64`. Python is not required.
- Regression tests use temporary configuration/state and clean up on exit. Relevant coverage includes profile isolation, template synchronization, V2 migration, service templates, setup CLI/UI, maintenance ordering/restoration, the global cron job, BepInEx status, and image upgrades.
