#!/usr/bin/env bash
# Files under core/ must not name a harness, a harness variable, or a harness tool.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="${1:-core}"
[ -d "$ROOT" ] || exit 0

tokens='claude|cursor|anthropic|CLAUDE_PLUGIN_ROOT|CLAUDE\.md|\bAgent tool\b|\bTask tool\b|\.cursor/'
rc=0
while IFS= read -r f; do
  if grep -nEiI "$tokens" "$f" >/tmp/ap-neutral 2>/dev/null; then
    printf 'harness token in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-neutral; rc=1
  fi
done < <(find "$ROOT" -type f -name '*.md')
exit $rc
