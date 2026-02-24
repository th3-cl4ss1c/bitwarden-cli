#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bw_session.sh [--raw]

Ensures Bitwarden is authenticated and unlocked.
Outputs either:
  - export command (default): export BW_SESSION='...'
  - raw session key (--raw)

Examples:
  eval "$(scripts/bw_session.sh)"
  session="$(scripts/bw_session.sh --raw)"
USAGE
}

mode="export"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --raw)
      mode="raw"
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

if ! command -v bw >/dev/null 2>&1; then
  echo "bw CLI not found in PATH" >&2
  exit 127
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
eval "$($script_dir/bw_env.sh)"

read_status() {
  local payload="${1:-}"
  python3 - "$payload" <<'PY'
import json
import sys

payload = sys.argv[1] if len(sys.argv) > 1 else ""
status = "unknown"
session = ""

if payload:
    try:
        data = json.loads(payload)
        if isinstance(data, dict):
            status = str(data.get("status", "unknown"))
            session = str(data.get("sessionKey") or "")
    except Exception:
        pass

print(status)
print(session)
PY
}

session=""
status="unknown"

# Reuse a user-provided session key when possible to avoid interactive prompts.
if [[ -n "${BW_SESSION:-}" ]]; then
  if BW_NOINTERACTION=true bw list items --search "__codex_probe__" --session "$BW_SESSION" --raw >/dev/null 2>&1; then
    session="$BW_SESSION"
    status="unlocked"
  fi
fi

if [[ "$status" != "unlocked" ]]; then
  status_json="$(bw status --raw 2>/dev/null || true)"
  readarray -t parsed < <(read_status "$status_json")
  status="${parsed[0]:-unknown}"
  session="${parsed[1]:-}"
fi


if [[ "$status" == "unauthenticated" ]]; then
  echo "Bitwarden is unauthenticated. Running 'bw login'." >&2
  bw login >&2
  status="locked"
fi

if [[ "$status" != "unlocked" || -z "$session" ]]; then
  echo "Unlocking Bitwarden vault." >&2
  session="$(bw unlock --raw)"
fi

session="${session//$'\r'/}"
session="${session//$'\n'/}"

if [[ -z "$session" ]]; then
  echo "Failed to retrieve BW_SESSION." >&2
  exit 1
fi

if [[ "$mode" == "raw" ]]; then
  printf '%s\n' "$session"
else
  printf "export BW_SESSION='%s'\n" "$session"
fi
