#!/usr/bin/env bash
# Publishes the site to a small VPS: build here, copy the static files,
# let Caddy serve them with automatic HTTPS.
#
# Usage:
#   deploy.sh setup                  once per server: installs Docker, creates the folder
#   deploy.sh push [--allow-todos]   builds and publishes

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_config() {
  [ -n "$SITE_DOMAIN" ] || die "SITE_DOMAIN in kit.env is empty. Example: SITE_DOMAIN=musterbetrieb.at"
  [ -n "$DEPLOY_HOST" ] || die "DEPLOY_HOST in kit.env is empty. Example: DEPLOY_HOST=root@203.0.113.10"
}

remote() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$DEPLOY_HOST" "$@"; }

cmd_setup() {
  require_config
  info "Preparing server: $DEPLOY_HOST"
  remote "DEPLOY_PATH='$DEPLOY_PATH' bash -s" <<'REMOTE'
set -euo pipefail
SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | $SUDO sh
fi
$SUDO docker compose version >/dev/null
$SUDO mkdir -p "$DEPLOY_PATH/site" "$DEPLOY_PATH/caddy"
$SUDO chown -R "$(id -un)" "$DEPLOY_PATH"
if [ "$(id -u)" -ne 0 ]; then $SUDO usermod -aG docker "$(id -un)"; fi
if command -v ufw >/dev/null 2>&1 && $SUDO ufw status | grep -q "Status: active"; then
  $SUDO ufw allow 80/tcp >/dev/null
  $SUDO ufw allow 443 >/dev/null
fi
echo "Docker $(docker --version | cut -d' ' -f3 | tr -d ,) ready, folder $DEPLOY_PATH created"
REMOTE
  ok "Server is ready. Publish with: npm run deploy"
  info "The DNS record (A record) of $SITE_DOMAIN must point to the server's IP, otherwise Caddy cannot get a certificate."
}

write_caddyfile() {
  # $1 = target file. Appends one redirect block per alias domain.
  cp "$ROOT_DIR/deploy/caddy/Caddyfile" "$1"
  local alias
  for alias in $DOMAIN_ALIASES; do
    printf '\n%s {\n\tredir https://%s{uri} permanent\n}\n' "$alias" "$SITE_DOMAIN" >>"$1"
  done
}

cmd_push() {
  local allow_todos=0
  [ "${1:-}" = "--allow-todos" ] && allow_todos=1
  require_config

  cd "$ROOT_DIR"
  if [ "$allow_todos" -eq 0 ] && ! bash scripts/todos.sh --strict; then
    die "Publishing stopped: the content still contains placeholders. Replace them first, or publish them on purpose with --allow-todos."
  fi

  info "Building the website for https://$SITE_DOMAIN"
  npm run --silent build
  [ -f dist/index.html ] || die "The build did not produce dist/index.html."

  # Global on purpose: the EXIT trap runs after this function has returned.
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' EXIT
  mkdir -p "$stage/caddy"
  write_caddyfile "$stage/caddy/Caddyfile"
  cp "$ROOT_DIR/deploy/compose.yaml" "$stage/compose.yaml"
  printf 'DOMAIN=%s\n' "$SITE_DOMAIN" >"$stage/.env"

  info "Copying files to $DEPLOY_HOST:$DEPLOY_PATH"
  remote "mkdir -p '$DEPLOY_PATH/site' '$DEPLOY_PATH/caddy'" ||
    die "The server cannot be reached or is not prepared. Run this once: npm run deploy:setup"
  rsync -az --delete dist/ "$DEPLOY_HOST:$DEPLOY_PATH/site/"
  rsync -az "$stage/caddy/" "$DEPLOY_HOST:$DEPLOY_PATH/caddy/"
  rsync -az "$stage/compose.yaml" "$stage/.env" "$DEPLOY_HOST:$DEPLOY_PATH/"

  remote "cd '$DEPLOY_PATH' && docker compose up -d --quiet-pull && { docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true; }"

  if curl -fsS -o /dev/null --max-time 20 "https://$SITE_DOMAIN/"; then
    ok "Published: https://$SITE_DOMAIN/"
  else
    warn "The files were copied, but https://$SITE_DOMAIN/ does not respond yet."
    warn "Check the DNS record and the server log: ssh $DEPLOY_HOST 'cd $DEPLOY_PATH && docker compose logs --tail 40 caddy'"
    exit 1
  fi
}

case "${1:-}" in
  setup) cmd_setup ;;
  push) cmd_push "${2:-}" ;;
  *) die "Usage: deploy.sh <setup|push [--allow-todos]>" ;;
esac
