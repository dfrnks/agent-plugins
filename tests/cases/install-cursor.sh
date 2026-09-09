#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
./install.sh --harness cursor --project "$TMP" >/dev/null
[ -L "$TMP/.cursor/agents/task-test.md" ]
[ -L "$TMP/.cursor/commands/tdd-task.md" ]
[ -d "$TMP/.cursor/tdd/core" ]
./install.sh --harness cursor --project "$TMP" >/dev/null   # idempotent
[ -L "$TMP/.cursor/agents/task-test.md" ]
