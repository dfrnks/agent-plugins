#!/usr/bin/env bash
# Verifies every file listed in the manifest exists and has its required headings.
# Manifest format, one record per line:  <path>|<heading>;<heading>;…
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
MANIFEST="${1:-checks/manifest.txt}"
rc=0

while IFS='|' read -r path headings; do
  case "$path" in ''|'#'*) continue ;; esac
  if [ ! -f "$path" ]; then
    printf 'missing file: %s\n' "$path"; rc=1; continue
  fi
  [ -z "${headings:-}" ] && continue
  IFS=';' read -ra required <<< "$headings"
  for h in "${required[@]}"; do
    [ -z "$h" ] && continue
    if ! grep -qF "$h" "$path"; then
      printf 'missing heading in %s: %s\n' "$path" "$h"; rc=1
    fi
  done
done < "$MANIFEST"

exit $rc
