# AGENTS.md

This repository contains a Bash-based Valheim server monitoring/status project. The code is intentionally lightweight and system-oriented. Future AI interventions should be conservative, explicit, and keep behavior predictable.

## Project purpose

- Monitor a local Valheim dedicated server.
- Parse log files and maintain online/offline player state.
- Expose HTTP status and Discord webhook status updates.
- Provide a setup menu via `./setup` for system configuration.

## Important repository conventions

- This project targets bash on Linux.
- Most scripts source `.env` from the repository root.
- The root script `./setup` is an interactive installer/UI, not a generic library.
- Any script that is loaded with `source` must not execute the interactive menu automatically.
- Shell scripts should keep failure modes non-fatal when possible; invalid numeric config values should degrade to sane defaults instead of aborting the whole workflow.
- Errors that are not user-facing should be directed to `crash.log` at the repository root via `exec 2>>"$CWD/crash.log"` when appropriate.

## Directory map

- `setup` : interactive setup and service configuration tool
- `vss.log-filter` : log parser for Valheim events
- `status/` : HTTP and CLI status scripts
- `discord/` : Discord webhook sender and updates
- `launcher/` : server launcher helpers
- `examples/` : systemd and logrotate examples
- `lib/` : reusable shell helpers, if present
- `.env.dist` / `.env` : environment configuration

## Execution rules for AI work

### Safety and compatibility

- Prefer small, surgical edits over large rewrites.
- Preserve POSIX/bash compatibility and avoid introducing Python or other languages unless explicitly requested.
- Do not rely on non-standard `jq` or other optional tools unless the project already uses them.
- Keep line endings and script style consistent with the repo.
- Favor readable shell logic; this project is operational, not object-oriented.

### Environment and config

- Respect the `.env` contract and keep keys compatible with existing setup flow.
- When adding numeric config variables, validate them as integers and fall back to a safe default on parse failure.
- Do not silently remove required configuration; log the fallback to `stderr` and ensure it is saved to `crash.log`.

### Discord / webhook behavior

- Do not send duplicate Discord status messages in the same update cycle.
- When a webhook is configured to update an existing message, prefer `PATCH` and exit without a fallback `POST` unless the message truly does not exist.
- If a message was deleted or the webhook is invalid, degrade gracefully and continue without crashing the main script.

### Logging / crash handling

- If a script writes to stderr and must keep running, append the output to the repository-root `crash.log`.
- All warnings, errors, invalid values, debug traces, and recovery messages must go to `stderr`, not `stdout`.
- Keep crash log entries concise and timestamped when possible.
- Avoid dumping secret values or sensitive credentials into logs.

## Validation workflow

Before claiming a fix is complete, run the smallest relevant verification command.

Examples:

- Shell-lint style checks if available.
- Direct script execution or sourcing tests for changed scripts.
- Minimal regression checks for integer parsing/default behavior.

Do not claim “fixed” without fresh output proving the behavior.

## Typical commands

- Run setup interactively:
  - `./setup`
- Source the setup script safely (for testing helper functions):
  - `source ./setup`
- Run a minimal script check:
  - `bash -lc 'source ./setup >/tmp/vss.out 2>&1; echo $?'`
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
- Do not hardcode secrets or make the project auto-commit or auto-deploy.
- Do not commit or create git changes without explicit user request.
- Do not claim a fix without verification output.
