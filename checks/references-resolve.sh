#!/usr/bin/env bash
# Every core/…md path mentioned anywhere must exist.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then mapfile -t targets < <(git ls-files '*.md'); fi

rc=0
for f in "${targets[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in tests/fixtures/*) [ $# -gt 0 ] || continue ;; esac
  while IFS= read -r ref; do
    [ -f "$ref" ] || { printf 'dangling reference in %s: %s\n' "$f" "$ref"; rc=1; }
  done < <(grep -oE 'core/[A-Za-z0-9._/-]+\.md' "$f" | sort -u)
done
exit $rc
