#!/usr/bin/env bash
# Every core/phases/*.md and core/flows/*.md file must be referenced by at
# least one adapter file under adapters/<harness>/.
# An optional second argument overrides the directory scanned (used by the
# test suite to exercise a fixture without a real adapters/<harness> tree);
# production callers pass only the harness name.
set -uo pipefail
cd "$(dirname "$0")/.."
HARNESS="${1:?usage: adapters-cover-core.sh <harness> [adapter-dir]}"
DIR="${2:-adapters/$HARNESS}"
[ -d "$DIR" ] || { printf 'missing adapter directory: %s\n' "$DIR"; exit 1; }
rc=0
while IFS= read -r core_file; do
  if ! grep -rqF "$core_file" "$DIR"; then
    printf 'no %s adapter references %s\n' "$HARNESS" "$core_file"; rc=1
  fi
done < <(find core/phases core/flows -name '*.md')
exit $rc
