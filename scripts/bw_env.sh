#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bw_env.sh [--raw]

Prepare a writable BITWARDENCLI_APPDATA_DIR for the current shell.
Outputs either:
  - export command (default): export BITWARDENCLI_APPDATA_DIR='...'
  - raw path (--raw)

Behavior:
  - Prefer ~/.config/Bitwarden CLI when writable.
  - Fall back to /tmp/bitwarden-cli-<user> when default appdata is not writable.
  - When fallback is used, refresh fallback data.json from default data.json if available.
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

default_appdata="${HOME}/.config/Bitwarden CLI"
fallback_appdata="${TMPDIR:-/tmp}/bitwarden-cli-${USER:-$(id -u)}"
target_appdata=""

is_writable_dir() {
  local dir="$1"
  local probe
  mkdir -p "$dir" 2>/dev/null || return 1
  probe="$dir/.codex-probe-$$"
  mkdir "$probe" 2>/dev/null || return 1
  rmdir "$probe" 2>/dev/null || true
  return 0
}

if [[ -n "${BITWARDENCLI_APPDATA_DIR:-}" ]]; then
  target_appdata="$BITWARDENCLI_APPDATA_DIR"
else
  if is_writable_dir "$default_appdata"; then
    target_appdata="$default_appdata"
  else
    target_appdata="$fallback_appdata"
  fi
fi

mkdir -p "$target_appdata"

# Keep fallback state aligned with the user profile to avoid stale sessions.
if [[ "$target_appdata" != "$default_appdata" && -r "$default_appdata/data.json" ]]; then
  cp "$default_appdata/data.json" "$target_appdata/data.json" 2>/dev/null || true
fi

if [[ "$mode" == "raw" ]]; then
  printf '%s\n' "$target_appdata"
else
  printf "export BITWARDENCLI_APPDATA_DIR='%s'\n" "$target_appdata"
fi
