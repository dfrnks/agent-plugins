#!/usr/bin/env bash
# Every core/phases/*.md and core/flows/*.md file must be referenced by at
# least one adapter file under adapters/<harness>/. Claude Code's agent
# files are the one exception: they live at the plugin root's agents/
# directory (see .claude-plugin/plugin.json — a directory value under its
# "agents" key is silently ignored, so those files cannot live under
# adapters/ the way every other harness file does), so that harness is
# checked across two directories.
# An optional second argument overrides the directory scanned (used by the
# test suite to exercise a fixture without a real adapters/<harness> tree);
# production callers pass only the harness name.
set -uo pipefail
cd "$(dirname "$0")/.."
HARNESS="${1:?usage: adapters-cover-core.sh <harness> [adapter-dir]}"
if [ -n "${2:-}" ]; then
  DIRS=("$2")
elif [ "$HARNESS" = "claude-code" ]; then
  DIRS=("adapters/$HARNESS" "agents")
else
  DIRS=("adapters/$HARNESS")
fi
for d in "${DIRS[@]}"; do
  [ -d "$d" ] || { printf 'missing adapter directory: %s\n' "$d"; exit 1; }
done
rc=0
while IFS= read -r core_file; do
  found=0
  for d in "${DIRS[@]}"; do
    grep -rqF "$core_file" "$d" && { found=1; break; }
  done
  if [ "$found" -eq 0 ]; then
    printf 'no %s adapter references %s\n' "$HARNESS" "$core_file"; rc=1
  fi
done < <(find core/phases core/flows -name '*.md')
exit $rc
