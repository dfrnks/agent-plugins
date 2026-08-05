#!/usr/bin/env bash
# Rejects real-world identifiers. Structural patterns are built in; literal
# names come from $AGENT_PIPELINE_DENYLIST (one lowercase literal per line).
set -uo pipefail
cd "$(dirname "$0")/.."

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  mapfile -t targets < <(git ls-files)
fi

# Structural: absolute home paths and email addresses. Each entry is
# "<kind>:<regex>" — the kind tells is_allowlisted() which segment of the
# match to check for an exact allowlist hit.
# Repository-owner handles are deliberately NOT matched: installation
# instructions cannot work without naming this repository.
patterns=(
  'home:/home/[A-Za-z0-9._-]+/'
  'home:/Users/[A-Za-z0-9._-]+/'
  'email:[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
)

# Known-invented placeholder tokens. A structural regex above cannot tell a
# real identifier from an invented example used in documentation or fixtures,
# so a match is only treated as a leak when its relevant segment (the email
# domain, or the home-path username) is EXACTLY one of these tokens — never
# by substring containment. Containment would let a real identifier like
# "notexample.com" or "thisisnotsomeuser" through just because it happens to
# contain an allowlisted token. This allowlist exists solely to let
# illustrative placeholders pass; it deliberately does not exempt whole files
# or directories (other than the checker/runner/fixtures self-exemption
# below), so a genuine leak sitting next to a placeholder is still caught.
# Growing this list weakens the check: every token added here can no longer
# be flagged anywhere in the repository. Add to it only when a new
# placeholder is genuinely needed for documentation — never to silence a
# real finding.
allowlist_domains=(
  'example.com'
  'example-company.com'
  'example.org'
)
allowlist_usernames=(
  'someuser'
)
# Not matched by either structural pattern above (no regex here targets
# literal project names) — kept for parity with the documented minimum list
# in case a future pattern references one.
allowlist_literals=(
  'my-app'
)

is_allowlisted() { # <kind> <matched text>
  local kind="$1" match="$2" candidate item
  case "$kind" in
    home)
      candidate="${match#/home/}"
      candidate="${candidate#/Users/}"
      candidate="${candidate%/}"
      for item in "${allowlist_usernames[@]}"; do
        [ "$candidate" = "$item" ] && return 0
      done
      ;;
    email)
      candidate="${match#*@}"
      for item in "${allowlist_domains[@]}"; do
        [ "$candidate" = "$item" ] && return 0
      done
      ;;
  esac
  return 1
}

# Scratch files go under a per-run mktemp directory, not a fixed /tmp path:
# a fixed name collides when two runs overlap (a developer and a hook, or two
# checkouts) and is a symlink-attack target on a shared /tmp.
#
# Stop if it cannot be created. This script does not set -e, so an unchecked
# failure would leave SCRATCH empty and the denylist redirection below would
# target an absolute path at the filesystem root: the write fails, grep's exit
# status is read anyway, and the denylist reports clean without having examined
# anything. A checker that passes because it could not run is worse than one
# that fails.
SCRATCH="$(mktemp -d)" || { echo "cannot create a scratch directory" >&2; exit 2; }
trap 'rm -rf "$SCRATCH"' EXIT

rc=0
for f in "${targets[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in checks/no-leakage.sh|tests/run.sh|tests/fixtures/*) [ $# -gt 0 ] || continue ;; esac
  for pk in "${patterns[@]}"; do
    kind="${pk%%:*}"
    p="${pk#*:}"
    while IFS=: read -r lineno match; do
      [ -z "${lineno:-}" ] && continue
      is_allowlisted "$kind" "$match" && continue
      printf 'leak in %s:\n  %s:%s\n' "$f" "$lineno" "$match"; rc=1
    done < <(grep -noEI "$p" "$f" 2>/dev/null)
  done
  if [ -n "${AGENT_PIPELINE_DENYLIST:-}" ] && [ -f "$AGENT_PIPELINE_DENYLIST" ]; then
    if grep -nIiFf "$AGENT_PIPELINE_DENYLIST" "$f" >"$SCRATCH/denylist" 2>/dev/null; then
      printf 'denylisted term in %s:\n' "$f"; sed 's/^/  /' "$SCRATCH/denylist"; rc=1
    fi
  fi
done
exit $rc
