# Bitwarden CLI Commands

## Prerequisites

- Install and verify `bw`:

```bash
command -v bw
bw --version
```

- Prepare writable appdata (important in sandboxed/agent runs):

```bash
eval "$(scripts/bw_env.sh)"
```

- Ensure current account context:

```bash
bw config server
bw status --raw
```

## Session Management

Login if unauthenticated:

```bash
bw login
```

Unlock and set session in current shell:

```bash
export BW_SESSION="$(bw unlock --raw)"
```

Or via skill helper:

```bash
eval "$(scripts/bw_session.sh)"
```

Lock or logout:

```bash
bw lock
bw logout
```

## Read and Search

List items:

```bash
bw list items --raw
```

Search by text:

```bash
bw list items --search "github" --raw
```

Read one item JSON:

```bash
bw get item "<item-id>" --raw
```

Read password only:

```bash
bw get password "<item-id>" --raw
```

Read TOTP code:

```bash
bw get totp "<item-id>" --raw
```

Read one field with an explicit session key:

```bash
scripts/bw_get_secret.sh --item "Prod API" --field custom:API_KEY --session "<BW_SESSION>"
```

## Create Item (Login Type)

1. Build JSON from template:

```bash
bw get template item > /tmp/item.json
```

2. Edit `/tmp/item.json` fields:
- `name`
- `type` as `1` for login
- `login.username`
- `login.password`
- `login.uris`

3. Encode and create:

```bash
bw create item "$(bw encode < /tmp/item.json)"
```

## Edit Existing Item

```bash
bw get item "<item-id>" --raw > /tmp/item.json
# edit fields
bw edit item "<item-id>" "$(bw encode < /tmp/item.json)"
```

## Attachments

List attachments for an item:

```bash
bw get item "<item-id>" --raw
```

Create attachment:

```bash
bw create attachment --itemid "<item-id>" /path/to/file
```

Download attachment:

```bash
bw get attachment "<attachment-id>" --itemid "<item-id>" --output /path/to/output
```

## Password Generation

```bash
bw generate --length 24 --uppercase --lowercase --number --special
```

Passphrase generation:

```bash
bw generate --passphrase --words 5 --separator -
```

## Safe Automation Patterns

- Prefer `--raw` in scripts.
- Pass values through stdin where possible.
- Avoid writing secrets to persistent files.
- Clear temporary files immediately after use if they contain secrets.
