#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bw_get_secret.sh --item <name> [--field <field>] [--json]
  bw_get_secret.sh --id <item-id> [--field <field>] [--json]

Options:
  --item <name>      Find item by search and prefer exact name match.
  --id <item-id>     Read item by exact Bitwarden item ID.
  --field <field>    Field to return (default: password).
                     Supported: password, username, uri, notes, totp,
                     name, id, custom:FIELD_NAME
  --json             Print full item JSON.
  -h, --help         Show help.

Examples:
  scripts/bw_get_secret.sh --item "GitHub" --field password
  scripts/bw_get_secret.sh --id "<uuid>" --field username
  scripts/bw_get_secret.sh --item "Prod API" --field custom:API_KEY
USAGE
}

item_query=""
item_mode=""
field="password"
print_json=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --item)
      [[ $# -ge 2 ]] || { echo "--item requires a value" >&2; exit 2; }
      item_query="$2"
      item_mode="name"
      shift 2
      ;;
    --id)
      [[ $# -ge 2 ]] || { echo "--id requires a value" >&2; exit 2; }
      item_query="$2"
      item_mode="id"
      shift 2
      ;;
    --field)
      [[ $# -ge 2 ]] || { echo "--field requires a value" >&2; exit 2; }
      field="$2"
      shift 2
      ;;
    --json)
      print_json=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$item_mode" || -z "$item_query" ]]; then
  echo "Either --item or --id must be provided." >&2
  usage >&2
  exit 2
fi

if ! command -v bw >/dev/null 2>&1; then
  echo "bw CLI not found in PATH" >&2
  exit 127
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${BW_SESSION:-}" ]]; then
  # shellcheck disable=SC1091
  eval "$($script_dir/bw_session.sh)"
fi

if [[ "$item_mode" == "id" ]]; then
  item_json="$(bw get item "$item_query" --raw)"
else
  search_json="$(bw list items --search "$item_query" --raw)"
  if ! item_json="$(python3 - "$item_query" <<'PY'
import json
import sys

needle = (sys.argv[1] if len(sys.argv) > 1 else "").strip().lower()

try:
    items = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

if not isinstance(items, list):
    raise SystemExit(1)

picked = None
for item in items:
    if not isinstance(item, dict):
        continue
    name = str(item.get("name") or "").strip().lower()
    if needle and name == needle:
        picked = item
        break

if picked is None:
    for item in items:
        if isinstance(item, dict):
            picked = item
            break

if picked is None:
    raise SystemExit(1)

print(json.dumps(picked))
PY
<<<"$search_json")"; then
    echo "No Bitwarden item found for: $item_query" >&2
    exit 1
  fi
fi

if [[ "$print_json" -eq 1 ]]; then
  printf '%s\n' "$item_json"
  exit 0
fi

item_id="$(python3 - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

print(str(data.get("id") or ""))
PY
<<<"$item_json")"

if [[ "$field" == "totp" ]]; then
  if [[ -z "$item_id" ]]; then
    echo "Could not resolve item ID for TOTP retrieval." >&2
    exit 1
  fi
  bw get totp "$item_id" --raw
  exit 0
fi

if ! python3 - "$field" <<'PY'
import json
import sys

field = sys.argv[1] if len(sys.argv) > 1 else "password"

try:
    item = json.load(sys.stdin)
except Exception:
    raise SystemExit(2)

if not isinstance(item, dict):
    raise SystemExit(2)

login = item.get("login") if isinstance(item.get("login"), dict) else {}
value = None

if field == "password":
    value = login.get("password")
elif field == "username":
    value = login.get("username")
elif field == "uri":
    uris = login.get("uris") if isinstance(login.get("uris"), list) else []
    if uris and isinstance(uris[0], dict):
        value = uris[0].get("uri")
elif field == "notes":
    value = item.get("notes")
elif field == "name":
    value = item.get("name")
elif field == "id":
    value = item.get("id")
elif field.startswith("custom:"):
    wanted = field.split(":", 1)[1].strip().lower()
    fields = item.get("fields") if isinstance(item.get("fields"), list) else []
    for custom in fields:
        if not isinstance(custom, dict):
            continue
        custom_name = str(custom.get("name") or "").strip().lower()
        if wanted and custom_name == wanted:
            value = custom.get("value")
            break
else:
    raise SystemExit(2)

if value is None or str(value) == "":
    raise SystemExit(1)

print(str(value))
PY
<<<"$item_json"; then
  echo "Requested field '$field' is missing or unsupported." >&2
  exit 1
fi
