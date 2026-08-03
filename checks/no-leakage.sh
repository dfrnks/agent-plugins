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

# Known-invented placeholder tokens. A structural regex above cannot tell a
# real identifier from an invented example used in documentation or fixtures,
# so a match is only treated as a leak when it does NOT contain one of these
# tokens. This allowlist exists solely to let illustrative placeholders pass;
# it deliberately does not exempt whole files or directories (other than the
# checker/runner/fixtures self-exemption below), so a genuine leak sitting
# next to a placeholder is still caught. Growing this list weakens the check:
# every token added here can no longer be flagged anywhere in the repository.
# Add to it only when a new placeholder is genuinely needed for
# documentation — never to silence a real finding.
allowlist=(
  'someuser'
  'example.com'
  'example-company.com'
  'example.org'
  'my-app'
)

is_allowlisted() {
  local text="$1" tok
  for tok in "${allowlist[@]}"; do
    case "$text" in *"$tok"*) return 0 ;; esac
  done
  return 1
}

rc=0
for f in "${targets[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in checks/no-leakage.sh|tests/run.sh|tests/fixtures/*) [ $# -gt 0 ] || continue ;; esac
  for p in "${patterns[@]}"; do
    while IFS=: read -r lineno match; do
      [ -z "${lineno:-}" ] && continue
      is_allowlisted "$match" && continue
      printf 'leak in %s:\n  %s:%s\n' "$f" "$lineno" "$match"; rc=1
    done < <(grep -noEI "$p" "$f" 2>/dev/null)
  done
  if [ -n "${AGENT_PIPELINE_DENYLIST:-}" ] && [ -f "$AGENT_PIPELINE_DENYLIST" ]; then
    if grep -nIiFf "$AGENT_PIPELINE_DENYLIST" "$f" >/tmp/ap-leak 2>/dev/null; then
      printf 'denylisted term in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-leak; rc=1
    fi
  fi
done
exit $rc
