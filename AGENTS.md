# AGENTS.md

This repository contains a Bash-based Valheim server monitoring/status project. The code is intentionally lightweight and system-oriented. Future AI interventions should be conservative, explicit, and keep behavior predictable.

## Project purpose

- Monitor a local Valheim dedicated server.
- Parse log files and maintain online/offline player state.
- Expose HTTP status and Discord webhook status updates.
- Provide a setup menu via `./setup` for system configuration.

## Important repository conventions

- This project targets bash on Linux.
- Runtime scripts load an explicit `.env.<world-name>` profile through `lib/config.sh`; `.env.dist` is only a template and `.env` is not an active configuration.
- The root script `./setup` is an interactive installer/UI, not a generic library.
- Any script that is loaded with `source` must not execute the interactive menu automatically.
- Shell scripts should keep failure modes non-fatal when possible; invalid numeric config values should degrade to sane defaults instead of aborting the whole workflow.
- Background VSS processes may append non-user-facing errors to `crash.log` at the repository root. The interactive `setup` CLI must keep its diagnostics visible and must not redirect its stderr to `crash.log`.

## Directory map

- `setup` : interactive setup and service configuration tool
- `vss.log-filter` : log parser for Valheim events
- `status/` : HTTP and CLI status scripts
- `discord/` : Discord webhook sender and updates
- `launcher/` : server launcher helpers
- `examples/` : systemd and logrotate examples
- `lib/` : reusable shell helpers, if present
- `.env.dist` / `.env.<world-name>` : configuration template and per-world configuration
- `launcher/launcher-args.<world-name>` : per-world optional launcher arguments

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
- Preserve migration from a legacy `.env` and `launcher/launcher-args` into profile-specific names; never overwrite an existing profile or state file.
- When adding numeric config variables, validate them as integers and fall back to a safe default on parse failure.
- Do not silently remove required configuration; log the fallback to `stderr` and ensure it is saved to `crash.log`.

### Discord / webhook behavior

- Do not send duplicate Discord status messages in the same update cycle.
- When a webhook is configured to update an existing message, prefer `PATCH` and exit without a fallback `POST` unless the message truly does not exist.
- If a message was deleted or the webhook is invalid, degrade gracefully and continue without crashing the main script.

### Logging / crash handling

- If a background/runtime script writes to stderr and must keep running, append the output to the repository-root `crash.log`. Interactive setup diagnostics should remain visible to the user and must not be redirected there.
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
- Tail the crash log:
  - `tail -f ./crash.log`

## Preferred AI behavior

- Explain the root cause before patching.
- Keep changes minimal and directly tied to the bug.
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
