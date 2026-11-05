#!/usr/bin/env bash
# Shows the state of every part of the setup.

set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS="$ROOT_DIR/scripts"

info "Website: $SITE_SLUG · Skill: /$SKILL_NAME"
info "Ordner:  $ROOT_DIR"
in_synced_folder && warn "Das Repo liegt in einem iCloud-synchronisierten Ordner. Verschiebe es nach ~/Developer."

info ""
info "Vorschau"
bash "$SCRIPTS/preview.sh" status
if [ -n "$LAN_PORT" ]; then info "  WLAN-Port: $LAN_PORT"; fi

info ""
info "OpenClaw"
bash "$SCRIPTS/openclaw.sh" status

info ""
info "Inhalt"
if grep -q '^Status: open' "$ROOT_DIR/BRIEF.md" 2>/dev/null; then
  warn "Das Onboarding ist noch offen (BRIEF.md)."
else
  ok "Onboarding begonnen oder abgeschlossen (BRIEF.md)"
fi
bash "$SCRIPTS/todos.sh"

info ""
info "Veröffentlichung"
if [ -n "$SITE_DOMAIN" ] && [ -n "$DEPLOY_HOST" ]; then
  ok "Ziel: https://$SITE_DOMAIN auf $DEPLOY_HOST:$DEPLOY_PATH"
else
  warn "SITE_DOMAIN und DEPLOY_HOST in kit.env sind noch leer."
fi
exit 0
