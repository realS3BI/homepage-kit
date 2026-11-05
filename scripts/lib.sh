#!/usr/bin/env bash
# Shared settings and helpers. Source this file; do not run it.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
# shellcheck disable=SC1091
source "$ROOT_DIR/kit.env"
if [ -f "$ROOT_DIR/kit.local.env" ]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/kit.local.env"
fi
set +a

info() { printf '%s\n' "$*"; }
ok() { printf '✓ %s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }
die() {
  printf '✗ %s\n' "$*" >&2
  exit 1
}

# setup.sh sets KIT_FORCE_* to address an older installation after the settings changed.
SITE_SLUG="${KIT_FORCE_SLUG:-${SITE_SLUG:-homepage}}"
case "$SITE_SLUG" in
  *[!a-z0-9-]* | -* | '') die "SITE_SLUG in kit.env may only contain lowercase letters, digits and hyphens (currently: '$SITE_SLUG')." ;;
esac

SKILL_NAME="${KIT_FORCE_SKILL:-${SKILL_NAME:-$SITE_SLUG}}"
case "$SKILL_NAME" in
  *[!a-z0-9-]* | -* | '') die "SKILL_NAME in kit.env may only contain lowercase letters, digits and hyphens (currently: '$SKILL_NAME')." ;;
esac
SKILL_TRIGGERS="${SKILL_TRIGGERS:-}"

PREVIEW_PORT="${KIT_FORCE_PORT:-${PREVIEW_PORT:-4321}}"
case "$PREVIEW_PORT" in
  *[!0-9]* | '') die "PREVIEW_PORT in kit.env must be a number (currently: '$PREVIEW_PORT')." ;;
esac

LAN_PORT="${LAN_PORT:-}"
SITE_DOMAIN="${SITE_DOMAIN:-}"
DOMAIN_ALIASES="${DOMAIN_ALIASES:-}"
DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/sites/$SITE_SLUG}"
WATCHDOG_ALERT_TO="${WATCHDOG_ALERT_TO:-}"

STATE_DIR="$ROOT_DIR/.kit"
PREVIEW_LABEL="dev.homepage-kit.$SITE_SLUG.preview"
LAN_LABEL="dev.homepage-kit.$SITE_SLUG.lan"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
HEALTH_URL="http://127.0.0.1:$PREVIEW_PORT/"
WATCHDOG_NAME="Website preview watchdog ($SITE_SLUG)"
# Name used by earlier versions of the kit. Setup and uninstall remove jobs under it too.
WATCHDOG_LEGACY_NAME="Website-Vorschau-Wächter ($SITE_SLUG)"

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

is_live() { curl -fsS -o /dev/null --max-time 8 "$HEALTH_URL" 2>/dev/null; }

wait_live() {
  local tries="${1:-30}"
  while [ "$tries" -gt 0 ]; do
    if is_live; then return 0; fi
    sleep 1
    tries=$((tries - 1))
  done
  return 1
}

port_in_use() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

find_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    command -v tailscale
  elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
    echo /Applications/Tailscale.app/Contents/MacOS/Tailscale
  else
    return 1
  fi
}

# Prints this machine's tailnet DNS name, e.g. mac-mini.example.ts.net
tailnet_host() {
  local ts
  ts="$(find_tailscale)" || return 1
  "$ts" status --json 2>/dev/null |
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const n=(JSON.parse(s).Self.DNSName||"").replace(/\.$/,"");if(!n)process.exit(1);console.log(n)}catch{process.exit(1)}})'
}

tailnet_url() {
  local host
  host="$(tailnet_host)" || return 1
  echo "https://$host:$PREVIEW_PORT/"
}

# iCloud can evict files from these folders, which breaks the background preview.
in_synced_folder() {
  case "$ROOT_DIR" in
    "$HOME/Documents"/* | "$HOME/Desktop"/* | "$HOME/Library/Mobile Documents"/*) return 0 ;;
    *) return 1 ;;
  esac
}
