#!/usr/bin/env bash
# Installs the OpenClaw skill for this website and a watchdog job that
# restarts the preview when it stops answering. Skills that belong to
# another project are never overwritten or removed.
#
# Usage: openclaw.sh <install|uninstall|status>

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

have_openclaw() { command -v openclaw >/dev/null 2>&1; }

workspace_dir() {
  local ws
  ws="$(openclaw config get agents.defaults.workspace 2>/dev/null | tail -n 1 || true)"
  case "$ws" in
    /*) echo "$ws" ;;
    *) echo "$HOME/.openclaw/workspace" ;;
  esac
}

skill_dir() { echo "$(workspace_dir)/skills/$SKILL_NAME"; }

# Prints the ids of all watchdog jobs that belong to this website.
# With "all", also those under the legacy name.
watchdog_ids() {
  local legacy=""
  [ "${1:-}" = all ] && legacy="$WATCHDOG_LEGACY_NAME"
  openclaw cron list --json 2>/dev/null | WATCHDOG_NAME="$WATCHDOG_NAME" WATCHDOG_LEGACY_NAME="$legacy" node -e '
    let s = ""
    process.stdin.on("data", (d) => (s += d)).on("end", () => {
      try {
        const start = s.search(/[\[{]/)
        const data = JSON.parse(s.slice(start))
        const jobs = Array.isArray(data) ? data : data.jobs || data.items || []
        const names = [process.env.WATCHDOG_NAME, process.env.WATCHDOG_LEGACY_NAME].filter(Boolean)
        for (const job of jobs) if (names.includes(job.name)) console.log(job.id)
      } catch {}
    })'
}

remove_watchdog() {
  local id
  for id in $(watchdog_ids all); do
    openclaw cron rm "$id" >/dev/null 2>&1 || warn "Could not remove watchdog job $id."
  done
}

# True when the installed skill of this name points at this repo.
skill_is_ours() { grep -qF "$ROOT_DIR" "$(skill_dir)/SKILL.md" 2>/dev/null; }

install_skill() {
  local dir src preview_url out
  dir="$(skill_dir)"
  if [ -e "$dir" ] && ! skill_is_ours; then
    die "OpenClaw already has a skill /$SKILL_NAME that does not belong to this repo. Choose another name: npm run setup -- --skill <name>"
  fi

  src="$STATE_DIR/skill"
  preview_url="$(tailnet_url 2>/dev/null || echo "$HEALTH_URL")"
  rm -rf "$src"
  mkdir -p "$src"
  REPO="$ROOT_DIR" SKILL="$SKILL_NAME" TRIGGERS="$SKILL_TRIGGERS" LOCAL_URL="$HEALTH_URL" PREVIEW_URL="$preview_url" \
    node -e '
      const fs = require("node:fs")
      const env = process.env
      // The description decides when OpenClaw picks the skill. It is written as a
      // quoted string because the trigger words may contain YAML syntax.
      let description =
        `Maintain the website in the repo ${env.REPO}. Use for /${env.SKILL} or whenever someone wants to ` +
        `change the texts, images, opening hours or design of the website, send examples or material for it, ` +
        `check the preview or publish the website. Requests may come in German or any other language.`
      if (env.TRIGGERS) description += ` Also use for these keywords: ${env.TRIGGERS}.`
      let text = fs.readFileSync(process.argv[1], "utf8")
      text = text.split("{{DESCRIPTION}}").join(JSON.stringify(description))
      for (const key of ["REPO", "SKILL", "LOCAL_URL", "PREVIEW_URL"]) {
        text = text.split(`{{${key}}}`).join(env[key])
      }
      fs.writeFileSync(process.argv[2], text)
    ' "$ROOT_DIR/openclaw/SKILL.md.tmpl" "$src/SKILL.md"

  # OpenClaw only lists skills that went through its own installer.
  if ! out="$(openclaw skills install "$src" --as "$SKILL_NAME" --force --acknowledge-install-policy-warning 2>&1)"; then
    warn "Could not install the skill. OpenClaw said: $(printf '%s' "$out" | tail -n 3)"
    return 1
  fi
  ok "OpenClaw skill installed: /$SKILL_NAME"
  [ -z "$SKILL_TRIGGERS" ] || info "  Also triggers on: $SKILL_TRIGGERS"
}

install_watchdog() {
  local out id channel
  remove_watchdog
  if ! out="$(openclaw cron add \
    --name "$WATCHDOG_NAME" \
    --description "Checks the website preview every 5 minutes and restarts it when needed." \
    --every 5m \
    --session isolated \
    --no-deliver \
    --command-argv "[\"/bin/bash\",\"$ROOT_DIR/scripts/preview.sh\",\"check\"]" \
    --command-cwd "$ROOT_DIR" \
    --command-env "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    --json 2>&1)"; then
    warn "Could not create the watchdog job. launchd still restarts the preview after a crash."
    warn "OpenClaw said: $(printf '%s' "$out" | tail -n 3)"
    return 0
  fi
  ok "Watchdog job created: $WATCHDOG_NAME (every 5 minutes)"

  [ -n "$WATCHDOG_ALERT_TO" ] || return 0
  id="$(watchdog_ids | head -n 1)"
  channel="${WATCHDOG_ALERT_TO%%:*}"
  if [ -n "$id" ] && openclaw cron edit "$id" \
    --failure-alert \
    --failure-alert-after 2 \
    --failure-alert-channel "$channel" \
    --failure-alert-to "$WATCHDOG_ALERT_TO" \
    --failure-alert-cooldown 1h >/dev/null 2>&1; then
    ok "Alert to $WATCHDOG_ALERT_TO after two failures"
  else
    warn "Could not set up the alert to $WATCHDOG_ALERT_TO."
  fi
}

cmd_install() {
  if ! have_openclaw; then
    warn "OpenClaw is not installed, skipping the skill and the watchdog."
    warn "After installing OpenClaw, run this again: npm run setup"
    return 0
  fi
  install_skill
  install_watchdog
}

cmd_uninstall() {
  have_openclaw || return 0
  remove_watchdog
  if skill_is_ours; then rm -rf "$(skill_dir)"; fi
  ok "OpenClaw skill and watchdog job removed"
}

cmd_status() {
  if ! have_openclaw; then
    warn "OpenClaw is not installed"
    return 0
  fi
  if skill_is_ours && openclaw skills info "$SKILL_NAME" 2>/dev/null | grep -q "Ready"; then
    ok "OpenClaw skill ready: /$SKILL_NAME"
  else
    warn "OpenClaw skill missing or not ready: /$SKILL_NAME"
  fi
  if [ -n "$(watchdog_ids)" ]; then ok "Watchdog job present: $WATCHDOG_NAME"; else warn "Watchdog job missing: $WATCHDOG_NAME"; fi
}

case "${1:-}" in
  install) cmd_install ;;
  uninstall) cmd_uninstall ;;
  status) cmd_status ;;
  *) die "Usage: openclaw.sh <install|uninstall|status>" ;;
esac
