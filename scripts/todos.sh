#!/usr/bin/env bash
# Lists content that is not ready for the public: TODO markers and the demo flag.
#
# Usage: todos.sh [--strict]   (--strict exits 1 when something is open)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

cd "$ROOT_DIR"
open=0

if grep -Eq '^[[:space:]]*demo:[[:space:]]*true' src/content/business.ts; then
  warn "Sample content active: src/content/business.ts still has demo: true."
  open=1
fi

todos="$(grep -rn 'TODO' src/content || true)"
if [ -n "$todos" ]; then
  count="$(printf '%s\n' "$todos" | wc -l | tr -d ' ')"
  warn "$count open TODO markers in the content:"
  printf '%s\n' "$todos" | cut -c1-160 >&2
  open=1
fi

if [ "$open" -eq 0 ]; then
  ok "No open TODO markers, no sample content"
  exit 0
fi

[ "$STRICT" -eq 1 ] && exit 1
exit 0
