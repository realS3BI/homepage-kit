#!/usr/bin/env bash
# Setup on the Mac that hosts the preview. Safe to run again, also after
# changing the settings: an installation under the old names is removed first.
#
# Usage: setup.sh [--slug <name>] [--skill <name>] [--triggers "<words>"] [--port <n>]
#                 [--yes] [--no-tailscale] [--no-openclaw] [--uninstall]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT_DIR/scripts"
KIT_ENV="$ROOT_DIR/kit.env"
INSTALLED_FILE="$ROOT_DIR/.kit/installed"

USE_TAILSCALE=1
USE_OPENCLAW=1
UNINSTALL=0
ASK=1
NEW_SLUG=""
NEW_SKILL=""
NEW_TRIGGERS=""
NEW_PORT=""
SET_TRIGGERS=0

usage="Usage: setup.sh [--slug <name>] [--skill <name>] [--triggers \"<words>\"] [--port <n>] [--yes] [--no-tailscale] [--no-openclaw] [--uninstall]"

while [ $# -gt 0 ]; do
  case "$1" in
    --slug) NEW_SLUG="${2:?$usage}" ASK=0 && shift ;;
    --skill) NEW_SKILL="${2:?$usage}" ASK=0 && shift ;;
    --triggers) NEW_TRIGGERS="${2-}" SET_TRIGGERS=1 ASK=0 && shift ;;
    --port) NEW_PORT="${2:?$usage}" ASK=0 && shift ;;
    --yes) ASK=0 ;;
    --no-tailscale) USE_TAILSCALE=0 ;;
    --no-openclaw) USE_OPENCLAW=0 ;;
    --uninstall) UNINSTALL=1 ;;
    *)
      printf '✗ Unknown option: %s\n%s\n' "$1" "$usage" >&2
      exit 1
      ;;
  esac
  shift
done

# Reads one value from kit.env without the surrounding quotes.
current() {
  KEY="$1" node -e '
    const text = require("node:fs").readFileSync(process.argv[1], "utf8")
    const line = text.split("\n").filter((l) => l.startsWith(process.env.KEY + "=")).pop() || ""
    console.log(line.slice(process.env.KEY.length + 1).trim().replace(/^"(.*)"$/, "$1"))
  ' "$KIT_ENV"
}

# Writes one value into kit.env. Values with spaces are quoted so the shell can read the file.
store() {
  KEY="$1" VALUE="$2" node -e '
    const fs = require("node:fs")
    const { KEY, VALUE } = process.env
    const clean = VALUE.replace(/["$`\\\n]/g, "").trim()
    const line = `${KEY}=${/\s/.test(clean) ? `"${clean}"` : clean}`
    const lines = fs.readFileSync(process.argv[1], "utf8").split("\n")
    const index = lines.findIndex((l) => l.startsWith(KEY + "="))
    if (index === -1) lines.push(line)
    else lines[index] = line
    fs.writeFileSync(process.argv[1], lines.join("\n"))
  ' "$KIT_ENV"
}

ask() {
  # $1 = question, $2 = default. Prints the answer, or the default on Enter.
  local answer
  printf '%s [%s]: ' "$1" "$2" >&2
  IFS= read -r answer || answer=""
  printf '%s' "${answer:-$2}"
}

remove_installation() {
  bash "$SCRIPTS/openclaw.sh" uninstall
  bash "$SCRIPTS/preview.sh" unshare >/dev/null 2>&1 || true
  bash "$SCRIPTS/preview.sh" uninstall
}

if [ "$UNINSTALL" -eq 1 ]; then
  remove_installation
  rm -f "$INSTALLED_FILE"
  printf 'The repo itself stays unchanged.\n'
  exit 0
fi

[ "$(uname -s)" = "Darwin" ] || {
  printf '✗ The setup installs macOS services. On other systems: npm install && npm run dev\n' >&2
  exit 1
}
command -v node >/dev/null 2>&1 || {
  printf '✗ Node.js is missing. Install it with: brew install node\n' >&2
  exit 1
}
node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=23)?0:1)' || {
  printf '✗ Node.js %s is too old. Version 22.23 or newer is required: brew upgrade node\n' "$(node -v)" >&2
  exit 1
}

# Ask for the names in a terminal. Agents and scripts pass flags or --yes instead.
if [ "$ASK" -eq 1 ] && [ -t 0 ]; then
  printf 'Four short questions. Press Enter to keep the value in square brackets.\n\n'
  NEW_SLUG="$(ask 'Short name of the website (lowercase letters, digits, hyphens)' "$(current SITE_SLUG)")"
  skill_default="$(current SKILL_NAME)"
  NEW_SKILL="$(ask 'Name of the OpenClaw skill, you call it in the chat with /name' "${skill_default:-$NEW_SLUG}")"
  NEW_TRIGGERS="$(ask 'Keywords that also trigger the skill without /name (optional)' "$(current SKILL_TRIGGERS)")"
  SET_TRIGGERS=1
  NEW_PORT="$(ask 'Preview port' "$(current PREVIEW_PORT)")"
  printf '\n'
fi

[ -z "$NEW_SLUG" ] || store SITE_SLUG "$NEW_SLUG"
[ -z "$NEW_SKILL" ] || store SKILL_NAME "$NEW_SKILL"
[ "$SET_TRIGGERS" -eq 0 ] || store SKILL_TRIGGERS "$NEW_TRIGGERS"
[ -z "$NEW_PORT" ] || store PREVIEW_PORT "$NEW_PORT"

source "$SCRIPTS/lib.sh"

# Settings changed since the last setup: remove what runs under the old names.
installed_now="$SITE_SLUG|$SKILL_NAME|$PREVIEW_PORT"
if [ -f "$INSTALLED_FILE" ]; then
  installed_before="$(cat "$INSTALLED_FILE")"
  if [ "$installed_before" != "$installed_now" ]; then
    info "Settings changed, removing the old installation ($installed_before)"
    IFS='|' read -r old_slug old_skill old_port <<<"$installed_before"
    (
      export KIT_FORCE_SLUG="$old_slug" KIT_FORCE_SKILL="$old_skill" KIT_FORCE_PORT="$old_port"
      remove_installation
    )
  fi
fi

cd "$ROOT_DIR"
info "Website: $SITE_SLUG · Skill: /$SKILL_NAME · Port: $PREVIEW_PORT · Folder: $ROOT_DIR"

info "1/4 Installing dependencies"
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund --loglevel=error >/dev/null
else
  npm install --no-audit --no-fund --loglevel=error >/dev/null
fi
ok "Dependencies installed"

info "2/4 Setting up the preview service"
bash "$SCRIPTS/preview.sh" install
mkdir -p "$STATE_DIR"
printf '%s' "$installed_now" >"$INSTALLED_FILE"

info "3/4 Tailscale sharing"
if [ "$USE_TAILSCALE" -eq 1 ]; then
  bash "$SCRIPTS/preview.sh" share || warn "Without Tailscale the preview is only reachable on this machine. To add it later: npm run share"
else
  info "  skipped"
fi

info "4/4 OpenClaw skill and watchdog"
if [ "$USE_OPENCLAW" -eq 1 ]; then
  bash "$SCRIPTS/openclaw.sh" install
else
  info "  skipped"
fi

info ""
info "Done. Next step: send your OpenClaw \"/$SKILL_NAME let's get started\"."
info "The agent then asks for examples and material and asks questions about the business."
info "Check the status at any time: npm run status"
