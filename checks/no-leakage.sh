#!/usr/bin/env bash
# Rejects real-world identifiers. Structural patterns are built in; literal
# names come from $AGENT_PIPELINE_DENYLIST (one lowercase literal per line).
set -uo pipefail
cd "$(dirname "$0")/.."

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  mapfile -t targets < <(git ls-files)
fi

# Structural: absolute home paths and email addresses.
# Repository-owner handles are deliberately NOT matched: installation
# instructions cannot work without naming this repository.
patterns=(
  '/home/[A-Za-z0-9._-]+/'
  '/Users/[A-Za-z0-9._-]+/'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
)

rc=0
for f in "${targets[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in checks/no-leakage.sh|tests/run.sh|tests/fixtures/*) [ $# -gt 0 ] || continue ;; esac
  for p in "${patterns[@]}"; do
    if grep -nEI "$p" "$f" >/tmp/ap-leak 2>/dev/null; then
      printf 'leak in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-leak; rc=1
    fi
  done
  if [ -n "${AGENT_PIPELINE_DENYLIST:-}" ] && [ -f "$AGENT_PIPELINE_DENYLIST" ]; then
    if grep -nIiFf "$AGENT_PIPELINE_DENYLIST" "$f" >/tmp/ap-leak 2>/dev/null; then
      printf 'denylisted term in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-leak; rc=1
    fi
  fi
done
exit $rc
