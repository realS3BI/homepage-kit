#!/usr/bin/env bash
# Live preview service: one Astro dev server on loopback, kept alive by launchd,
# reachable in the tailnet through `tailscale serve`.
#
# Usage: preview.sh <install|uninstall|check|restart|status|logs|share|unshare|dev>

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PREVIEW_PLIST="$LAUNCH_AGENTS_DIR/$PREVIEW_LABEL.plist"
LAN_PLIST="$LAUNCH_AGENTS_DIR/$LAN_LABEL.plist"
ASTRO_BIN="$ROOT_DIR/node_modules/astro/bin/astro.mjs"
GUI_DOMAIN="gui/$(id -u)"

require_macos() {
  is_macos || die "The preview service uses launchd and only runs on macOS. On other systems: npm run dev"
}

write_plist() {
  # $1 = plist path, $2 = label, $3 = subcommand, $4 = log name
  local node_dir
  node_dir="$(dirname "$(command -v node)")"
  mkdir -p "$LAUNCH_AGENTS_DIR" "$STATE_DIR"
  cat >"$1" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$2</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$ROOT_DIR/scripts/preview.sh</string>
		<string>$3</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$node_dir:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
	</dict>
	<key>WorkingDirectory</key>
	<string>$ROOT_DIR</string>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>10</integer>
	<key>StandardOutPath</key>
	<string>$STATE_DIR/$4.log</string>
	<key>StandardErrorPath</key>
	<string>$STATE_DIR/$4.log</string>
</dict>
</plist>
PLIST
}

load_agent() {
  # $1 = plist path, $2 = label
  launchctl bootout "$GUI_DOMAIN/$2" >/dev/null 2>&1 || true
  # bootout returns before the old process is gone; bootstrap fails until then.
  local tries=10
  until launchctl bootstrap "$GUI_DOMAIN" "$1" >/dev/null 2>&1; do
    tries=$((tries - 1))
    [ "$tries" -gt 0 ] || die "launchd could not load $2. Check: launchctl print $GUI_DOMAIN/$2"
    sleep 1
  done
}

unload_agent() {
  # $1 = plist path, $2 = label
  launchctl bootout "$GUI_DOMAIN/$2" >/dev/null 2>&1 || true
  rm -f "$1"
}

agent_loaded() { launchctl print "$GUI_DOMAIN/$1" >/dev/null 2>&1; }

cmd_install() {
  require_macos
  command -v node >/dev/null 2>&1 || die "Node.js is missing. Install it with: brew install node"
  [ -f "$ASTRO_BIN" ] || die "Dependencies are missing. Run this first: npm install"

  if in_synced_folder; then
    warn "The repo is in a folder synced by iCloud ($ROOT_DIR)."
    warn "macOS can offload files from there, and then the preview fails with error -11. Move it to ~/Developer."
  fi

  if ! agent_loaded "$PREVIEW_LABEL" && port_in_use "$PREVIEW_PORT"; then
    die "Port $PREVIEW_PORT is already in use. Set a free PREVIEW_PORT in kit.env."
  fi

  write_plist "$PREVIEW_PLIST" "$PREVIEW_LABEL" run preview
  load_agent "$PREVIEW_PLIST" "$PREVIEW_LABEL"
  if wait_live 45; then
    ok "Preview running: $HEALTH_URL"
  else
    die "The preview does not respond. Log: $STATE_DIR/preview.log"
  fi

  if [ -n "$LAN_PORT" ]; then
    write_plist "$LAN_PLIST" "$LAN_LABEL" lan-run lan-proxy
    load_agent "$LAN_PLIST" "$LAN_LABEL"
    ok "Wi-Fi access active on port $LAN_PORT (no login, use only on a trusted network)"
  elif [ -f "$LAN_PLIST" ]; then
    unload_agent "$LAN_PLIST" "$LAN_LABEL"
  fi
}

cmd_uninstall() {
  require_macos
  unload_agent "$PREVIEW_PLIST" "$PREVIEW_LABEL"
  unload_agent "$LAN_PLIST" "$LAN_LABEL"
  ok "Preview services removed"
}

# Entry point for launchd. astro.config.mjs sets strictPort, so a taken port
# ends the process and launchd retries instead of serving on another port.
cmd_run() {
  cd "$ROOT_DIR"
  exec node "$ASTRO_BIN" dev --host 127.0.0.1 --port "$PREVIEW_PORT"
}

cmd_lan_run() {
  [ -n "$LAN_PORT" ] || die "LAN_PORT is not set."
  exec node "$ROOT_DIR/scripts/lan-proxy.mjs" "$LAN_PORT" "$PREVIEW_PORT"
}

kickstart() { launchctl kickstart -k "$GUI_DOMAIN/$PREVIEW_LABEL" >/dev/null 2>&1; }

# Health check for the watchdog. Exit 0 = healthy or repaired, 1 = still down.
cmd_check() {
  if is_live; then
    echo "Preview healthy: $HEALTH_URL"
    return 0
  fi
  require_macos
  [ -f "$PREVIEW_PLIST" ] || die "The preview service is not set up. Run: npm run setup"
  agent_loaded "$PREVIEW_LABEL" || launchctl bootstrap "$GUI_DOMAIN" "$PREVIEW_PLIST" >/dev/null 2>&1 || true

  kickstart || true
  if wait_live 30; then
    echo "Preview restarted: $HEALTH_URL"
    return 0
  fi

  # A stale dependency cache makes the dev server answer 504 until it is cleared.
  rm -rf "$ROOT_DIR/node_modules/.vite" "$ROOT_DIR/.astro"
  kickstart || true
  if wait_live 45; then
    echo "Preview restarted after clearing the cache: $HEALTH_URL"
    return 0
  fi

  echo "Preview does not start. Last log lines:" >&2
  tail -n 15 "$STATE_DIR/preview.log" >&2 2>/dev/null || true
  return 1
}

cmd_restart() {
  require_macos
  [ -f "$PREVIEW_PLIST" ] || die "The preview service is not set up. Run: npm run setup"
  agent_loaded "$PREVIEW_LABEL" || launchctl bootstrap "$GUI_DOMAIN" "$PREVIEW_PLIST" >/dev/null 2>&1 || true
  kickstart || true
  wait_live 45 || die "The preview does not respond after the restart. Log: $STATE_DIR/preview.log"
  ok "Preview restarted: $HEALTH_URL"
}

cmd_status() {
  if is_live; then ok "Preview responds: $HEALTH_URL"; else warn "Preview does not respond: $HEALTH_URL"; fi
  if is_macos; then
    if agent_loaded "$PREVIEW_LABEL"; then ok "launchd service loaded: $PREVIEW_LABEL"; else warn "launchd service not loaded: $PREVIEW_LABEL"; fi
  fi
  local url
  if url="$(tailnet_url)"; then info "  Tailscale address: $url"; fi
}

cmd_logs() { tail -n "${1:-60}" "$STATE_DIR/preview.log"; }

cmd_share() {
  local ts url
  ts="$(find_tailscale)" || die "Tailscale is missing. Install it from https://tailscale.com/download and sign in."
  "$ts" status >/dev/null 2>&1 || die "Tailscale is not connected. Open the Tailscale app and sign in."
  "$ts" serve --bg --https="$PREVIEW_PORT" "http://127.0.0.1:$PREVIEW_PORT" >/dev/null ||
    die "tailscale serve failed. In the Tailscale admin console under DNS, enable MagicDNS and HTTPS Certificates."
  url="$(tailnet_url)" || die "Could not determine the Tailscale address of this machine."
  ok "Reachable in the tailnet: $url"
}

cmd_unshare() {
  local ts
  ts="$(find_tailscale)" || die "Tailscale is missing."
  "$ts" serve --https="$PREVIEW_PORT" off >/dev/null
  ok "Stopped Tailscale sharing for port $PREVIEW_PORT"
}

# Manual dev server. Refuses to start a second one next to the service:
# two dev servers share one dependency cache and corrupt it.
cmd_dev() {
  if is_live; then
    info "The preview is already running: $HEALTH_URL"
    info "A second dev server would corrupt the shared cache. To check changes: npm run check"
    return 0
  fi
  cmd_run
}

case "${1:-}" in
  install) cmd_install ;;
  uninstall) cmd_uninstall ;;
  run) cmd_run ;;
  lan-run) cmd_lan_run ;;
  check) cmd_check ;;
  restart) cmd_restart ;;
  status) cmd_status ;;
  logs) cmd_logs "${2:-}" ;;
  share) cmd_share ;;
  unshare) cmd_unshare ;;
  dev) cmd_dev ;;
  *) die "Usage: preview.sh <install|uninstall|check|restart|status|logs|share|unshare|dev>" ;;
esac
