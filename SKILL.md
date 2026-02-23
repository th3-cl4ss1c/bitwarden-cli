---
name: bitwarden-cli
description: Use when Codex needs to store, retrieve, search, or update passwords, API tokens, secure notes, and custom fields in Bitwarden via the bw CLI, including login or unlock session handling and safe secret usage in shell workflows.
---

# Bitwarden CLI

Use this skill to run Bitwarden tasks through `bw` with repeatable, secure shell patterns.

## Quick Start

1. Check availability.

```bash
command -v bw
bw --version
```

2. Unlock and export a session.

```bash
eval "$(scripts/bw_session.sh)"
```

3. Read a secret by item name.

```bash
scripts/bw_get_secret.sh --item "GitHub" --field password
```

## Workflow

1. Inspect status with `bw status --raw`.
2. Authenticate if status is `unauthenticated` (`bw login`).
3. Unlock if status is `locked` (`bw unlock --raw`).
4. Export `BW_SESSION` only for the current shell.
5. Resolve item by ID for deterministic reads, or by search plus exact name match if ID is unknown.
6. Retrieve only requested fields.
7. Avoid printing secrets in logs, files, or command history.

## Common Tasks

Read item metadata without exposing secrets:

```bash
bw get item "<item-id>" --raw
```

List items by search text:

```bash
bw list items --search "github" --raw
```

Get password by ID:

```bash
bw get password "<item-id>" --raw
```

Create an item from a template:

```bash
bw get template item | python3 -m json.tool
```

Generate a password:

```bash
bw generate --length 24 --uppercase --lowercase --number --special
```

## Safety Rules

- Prefer `--raw` for script-friendly output.
- Keep `BW_SESSION` in process memory; do not write it to files.
- Avoid command patterns that echo secrets to terminal output unless the user explicitly asks.
- Prefer item ID over item name when multiple similar entries can exist.
- Confirm before mutating or deleting vault data.
- Use `bw lock` after completing sensitive operations.

## Bundled Resources

- `scripts/bw_session.sh`: Ensure authenticated and unlocked state, then print a shell export command.
- `scripts/bw_get_secret.sh`: Resolve an item and return one field (`password`, `username`, `uri`, `notes`, `totp`, `custom:FIELD`).
- `references/commands.md`: Extended command cookbook for CRUD and troubleshooting.

Read `references/commands.md` when full create or edit flows and JSON payload examples are required.
