#!/usr/bin/env bash
# Shows the state of every part of the setup.

set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS="$ROOT_DIR/scripts"

info "Website: $SITE_SLUG · Skill: /$SKILL_NAME"
info "Folder:  $ROOT_DIR"
in_synced_folder && warn "The repo is in a folder synced by iCloud. Move it to ~/Developer."

info ""
info "Preview"
bash "$SCRIPTS/preview.sh" status
if [ -n "$LAN_PORT" ]; then info "  Wi-Fi port: $LAN_PORT"; fi

info ""
info "OpenClaw"
bash "$SCRIPTS/openclaw.sh" status

info ""
info "Content"
if grep -q '^Status: open' "$ROOT_DIR/BRIEF.md" 2>/dev/null; then
  warn "Onboarding has not started yet (BRIEF.md)."
else
  ok "Onboarding in progress or done (BRIEF.md)"
fi
bash "$SCRIPTS/todos.sh"

info ""
info "Publishing"
if [ -n "$SITE_DOMAIN" ] && [ -n "$DEPLOY_HOST" ]; then
  ok "Target: https://$SITE_DOMAIN on $DEPLOY_HOST:$DEPLOY_PATH"
else
  warn "SITE_DOMAIN and DEPLOY_HOST in kit.env are still empty."
fi
exit 0
