#!/usr/bin/env bash
# Verifies every file listed in the manifest exists and has its required headings.
# Manifest format, one record per line:  <path>|<heading>;<heading>;…
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
MANIFEST="${1:-checks/manifest.txt}"
# Without this guard the redirect below fails, the loop body never runs, and
# rc stays 0 — a checker reporting a pass it never earned.
if [ ! -f "$MANIFEST" ] || [ ! -r "$MANIFEST" ]; then
  printf 'cannot read manifest: %s\n' "$MANIFEST" >&2
  exit 2
fi
rc=0
records=0

# Two deliberate choices here, each closing a silent pass. `|| [ -n "$line" ]`
# keeps the final record when the file ends without a newline; without it read
# returns non-zero at EOF and that row is never enforced. Reading the raw line
# rather than splitting on IFS is what tells a record missing its separator
# from one that legitimately declares no headings — both leave the headings
# variable empty, and only one of them is a mistake.
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  records=$((records + 1))
  case "$line" in
    *'|'*) ;;
    *) printf 'record has no separator: %s\n' "$line"; rc=1; continue ;;
  esac
  path="${line%%|*}"
  headings="${line#*|}"
  if [ -z "$path" ]; then
    printf 'record has an empty path: %s\n' "$line"; rc=1; continue
  fi
  if [ ! -f "$path" ]; then
    printf 'missing file: %s\n' "$path"; rc=1; continue
  fi
  [ -z "$headings" ] && continue
  named=0
  IFS=';' read -ra required <<< "$headings"
  for h in "${required[@]}"; do
    [ -z "$h" ] && continue
    named=$((named + 1))
    if ! grep -qF "$h" "$path"; then
      printf 'missing heading in %s: %s\n' "$path" "$h"; rc=1
    fi
  done
  if [ "$named" -eq 0 ]; then
    printf 'record names no heading: %s\n' "$line"; rc=1
  fi
done < "$MANIFEST"

# A manifest that declares nothing is a caller error, not a clean run: the
# only reason to invoke this checker is to enforce records.
if [ "$records" -eq 0 ]; then
  printf 'manifest declares no records: %s\n' "$MANIFEST" >&2
  exit 2
fi

exit $rc
