# AGENTS.md

This repository contains a Bash-based Valheim server monitoring/status project. The code is intentionally lightweight and system-oriented. Future AI interventions should be conservative, explicit, and keep behavior predictable.

## Project purpose

- Monitor a local Valheim dedicated server.
- Parse log files and maintain online/offline player state.
- Expose HTTP status and Discord webhook status updates.
- Provide a setup menu via `./setup` for system configuration.

## Important repository conventions

- This project targets bash on Linux.
- Runtime scripts load an explicit `.env.<world-name>` profile through `lib/config.sh`; `.env.server.dist` and `.env.common.dist` are templates, while the root `.env` stores shared installation settings.
- `VSSDIR` is the installation root shared by every profile. `setup` synchronizes newly added keys from `.env.common.dist` into the root `.env` without overwriting existing values.
- The root script `./setup` is an interactive installer/UI, not a generic library.
- In the interactive setup UI, preserve up/down arrow navigation, in-list selection highlighting, and numeric shortcuts. The profile overview belongs only in the initial selector and **Switch server profile**; keep profile questions above the input prompt and retain line-based input behavior when stdin is not a terminal.
- Any script that is loaded with `source` must not execute the interactive menu automatically.
- Shell scripts should keep failure modes non-fatal when possible; invalid numeric config values should degrade to sane defaults instead of aborting the whole workflow.
- Background VSS processes may append non-user-facing errors to `crash.log` at the repository root. The interactive `setup` CLI must keep its diagnostics visible and must not redirect its stderr to `crash.log`.

## Directory map

- `setup` : interactive setup and service configuration tool
- `migrate-v2-to-v3` : explicit, backed-up V2-to-V3 migration command
- `bepinex_upgrade.sh` : downloads the latest official Linux x64 BepInEx image and updates `bepinex/current`
- `vss.log-filter` : log parser for Valheim events
- `status/` : HTTP and CLI status scripts
- `discord/` : Discord webhook sender and updates
- `launcher/` : server launcher helpers
- `examples/` : systemd and logrotate examples
- `lib/` : reusable shell helpers, if present
- `.env.server.dist` / `.env.<world-name>` : per-server configuration template and configuration
- `.env.common.dist` / `.env` : shared configuration template and installation settings
- `launcher/launcher-args.<world-name>` : per-world optional launcher arguments
- `migration-backups/` : permission-restricted migration backups; ignored by git

## Execution rules for AI work

### Safety and compatibility

- Prefer small, surgical edits over large rewrites.
- Preserve POSIX/bash compatibility and avoid introducing Python or other languages unless explicitly requested.
- Do not rely on non-standard `jq` or other optional tools unless the project already uses them.
- Keep line endings and script style consistent with the repo.
- Favor readable shell logic; this project is operational, not object-oriented.

### Environment and config

- Pass the selected profile explicitly with `VSS_SERVER_NAME` to scripts, services, cron jobs, and child processes.
- Keep profile names equal to `VHSERVERWORLD`; validate names before using them in filenames or systemd unit names.
- Keep VSS state files isolated with world-name suffixes. The Valheim `savedir` and its admin, banned, and permitted lists are intentionally shared.
- `VHSERVERSEED` is informational only and is displayed in status/Discord; VSS cannot use it to set or change the Valheim world seed.
- `R2MODMANCODE` is an optional per-profile mod-manager share code. Display it in Discord and server status only when BepInEx is enabled; VSS does not generate or synchronize the mod profile.
- One Discord webhook URL and its send options, public IP, and VSS tool paths are shared in `.env`; separate webhook URLs per profile are not supported. Each profile uses one `STATUSMESSAGEID` for status, optional connection details, and optional logs. Old `LASTLOGMESSAGEID` and `SERVERCONNECTIONINFOMESSAGEID` values may be used as transition fallbacks when `STATUSMESSAGEID` is empty.
- Valheim server files are shared across profiles. Service startup must not run SteamCMD updates; use `./setup --maintenance-update`, which stops every installed Valheim service, updates once, then sequentially starts only those that were active before the request. `vss.maintenance` checks all profiles, uses the shared `VSS_LANG` for its warning, and should be scheduled once globally in root's crontab with `./setup --schedule-maintenance`, not once per profile.
- Setup validates port collisions between profiles using each Valheim base port and its next port, and may report UFW rules for that pair and the HTTP status port. The check is informational and must never modify or open firewall rules.
- Preserve migration from a legacy V2 `.env` into shared `.env` plus `.env.<world-name>`, and migrate `launcher/launcher-args` into a profile-specific name; never overwrite an existing profile or state file.
- `VSSBEPINEXDIR` and `VSSBEPINEXLOGOUTPUT` are per-profile settings. Keep plugins, plugin configuration, patchers, cache, and BepInEx logs in `bepinex/profiles/<world-name>/`; share `BepInEx.cfg`, `libdoorstop.so`, and immutable runtime files through file-level symlinks to `bepinex/current`, never symlink the profile directories themselves. BepInEx 5 derives its root from the full `DOORSTOP_INVOKE_DLL_PATH`; preserve the profile path to the preloader by not symlinking the `core` directory.
- The launcher must use that profile's `BepInEx.Preloader.dll` and root-level `libdoorstop.so` paths. When BepInEx is disabled, clear Doorstop variables, remove VSS BepInEx roots and legacy `doorstop_libs` entries from `LD_LIBRARY_PATH`, and remove only `libdoorstop.so` entries from `LD_PRELOAD`, preserving unrelated paths and preloads.
- The vanilla VSS launcher sends stdout directly to `vss.log-filter` and does not need `vss.pipe`. The standalone pipe also supports external servers whose logs are redirected to files. Enabling BepInEx stops a running managed server, prepares the profile, records whether a pipe was already installed in the internal `VSSPIPEPREEXISTING` profile setting, ensures the profile's `vss.pipe.<world-name>.service` is installed/running, and restarts the server. Disabling BepInEx stops a running managed server and removes the pipe only when BepInEx setup created it; a pre-existing pipe is kept for the external log source. It then restarts the server in vanilla mode. A stopped server stays stopped; setup refuses to switch an unmanaged running server.
- If `bepinex/current` is missing or broken when BepInEx is enabled, `bepinex/install_bepinex.sh` must download the latest image through `./bepinex_upgrade.sh`; that script creates `bepinex/current` and prepares all enabled profiles. Do not bundle the upstream BepInEx image in the repository.
- `./bepinex_upgrade.sh` requires `wget`, `unzip`, and `awk`. It enforces VSS-owned logging keys in the image's `BepInEx.cfg`, preserves other upstream config entries, and creates a minimal logging config if the archive omits the file; BepInEx fills in its other defaults on first launch. It migrates only existing plugins and plugin configuration to every enabled profile, switches or creates `bepinex/current`, then removes the previously active image. Do not migrate logs, cache, or patchers. A failure before switching leaves the old current link/image untouched; a post-switch synchronization failure attempts rollback and retains the old image, but filesystem failures can prevent complete restoration. The `BEPINEX_RELEASES_LATEST_URL` override is for a fixture-compatible release metadata endpoint.
- When adding numeric config variables, validate them as integers and fall back to a safe default on parse failure.
- Do not silently remove required configuration; show fallback and validation diagnostics on `stderr`. Background/runtime processes may additionally append operational errors to `crash.log`; the interactive `setup` CLI must not redirect there.

### Discord / webhook behavior

- Do not send duplicate Discord status messages in the same update cycle.
- When a webhook is configured to update an existing message, prefer `PATCH` and exit without a fallback `POST` unless the message truly does not exist.
- If a message was deleted or the webhook is invalid, degrade gracefully and continue without crashing the main script.

### Logging / crash handling

- If a background/runtime script writes to stderr and must keep running, append the output to the repository-root `crash.log`. Interactive setup diagnostics should remain visible to the user and must not be redirected there.
- Do not redirect `setup` stderr globally; when sourced, it must not alter the calling shell's stderr.
- Name generated logs `<date>.<world-name>.stdout.log` or `<date>.<world-name>.stderr.log`; all profiles use the shared logrotate configuration.
- All warnings, errors, invalid values, debug traces, and recovery messages must go to `stderr`, not `stdout`.
- Keep crash log entries concise and timestamped when possible.
- Avoid dumping secret values or sensitive credentials into logs.

## Validation workflow

Before claiming a fix is complete, run the smallest relevant verification command.

Examples:

- Shell-lint style checks if available.
- Direct script execution or sourcing tests for changed scripts.
- Minimal regression checks for integer parsing/default behavior.
- Profile-isolation and migration tests for changes to config loading or setup.
- Run `./tests/test_bepinex_upgrade.sh` for BepInEx image-upgrade changes; the test uses `wget`, `unzip`, `ncat`, and `base64` to exercise local HTTP/ZIP fixtures.
- Run `bash tests/test_bepinex_runtime.sh` to exercise concurrent modded/vanilla launches and verify profile-specific Doorstop environment isolation.
- Tests must put generated configuration, state, and log files in temporary directories, and remove them with an `EXIT` trap. Do not let tests touch active `.env.<world-name>` files, `data/`, production logs, or `crash.log`.
- After running tests, check for leftovers and verify that active profile files, state, logs, and `crash.log` are unchanged. Re-run the suite when practical to check idempotence.

Do not claim “fixed” without fresh output proving the behavior.

## Typical commands

- Run setup interactively:
  - `./setup`
- List or select a server profile:
  - `./setup --list`
  - `./setup <world-name>`
- Run a profile-specific command:
  - `VSS_SERVER_NAME=<world-name> ./discord/update`
- Source the setup script safely (for testing helper functions):
  - `source ./setup`
- Tail the runtime crash log (background/runtime processes only):
  - `tail -f ./crash.log`

## Preferred AI behavior

- Explain the root cause before patching.
- Keep changes minimal and directly tied to the bug.
- Keep `README.md` and `AGENTS.md` current at every intervention when behavior, dependencies, workflows, or repository conventions change; document user-facing operations in README and implementation guidance in AGENTS.
- Prefer defaults over aborts for malformed values.
- Preserve the project’s operational assumptions: Linux service management, bash, systemd, cron, Discord webhooks, and log parsing.

## Do not do

- Do not convert the project to another language.
- Do not add heavy dependencies or frameworks.
- Do not break the setup menu workflow.
- Do not silently fall back to a shared `.env` when no profile is selected.
- Do not hardcode secrets or make the project auto-commit or auto-deploy.
- Do not commit or create git changes without explicit user request.
- Do not claim a fix without verification output.
