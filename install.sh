#!/usr/bin/env bash
# Links this package's adapter into a target project.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
HARNESS=""; PROJECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --harness) HARNESS="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$HARNESS" ] && [ -n "$PROJECT" ] || {
  echo "usage: install.sh --harness <claude-code|cursor> --project <path>" >&2; exit 2; }
[ -d "$SRC/adapters/$HARNESS" ] || { echo "unknown harness: $HARNESS" >&2; exit 2; }
[ -d "$PROJECT" ] || { echo "no such project: $PROJECT" >&2; exit 2; }

# Claude Code adapters point at ${CLAUDE_PLUGIN_ROOT}/core/... — a variable
# that only resolves when Claude Code loads them through its own plugin
# system (a marketplace install with this repository's source at ".", see
# .claude-plugin/). Symlinking adapters/claude-code/ into a project's
# .claude/ directory would not make Claude Code set that variable, so every
# ${CLAUDE_PLUGIN_ROOT} reference would dangle — the exact class of
# install-time breakage this repository has already shipped once. This
# script therefore refuses the harness rather than producing a link layout
# that looks installed but cannot resolve its own core/ pointers.
if [ "$HARNESS" = "claude-code" ]; then
  cat >&2 <<'EOF'
install.sh does not install the Claude Code adapter: it ships as a Claude
Code plugin, not as project-local symlinks. ${CLAUDE_PLUGIN_ROOT} — the
variable every Claude Code adapter file uses to reach core/ — is only set
when Claude Code loads the adapter through its own plugin system, not
because matching files happen to exist under a project's .claude/ directory.

Install it instead via Claude Code's plugin flow:
  claude plugin marketplace add dfrnks/agent-plugins
  claude plugin install tdd-pipeline@dfrnks

The plugin is "tdd-pipeline"; the marketplace it comes from is "dfrnks". The
"@" form names both, so the install works the same way whether or not another
marketplace also offers a plugin by that name.
EOF
  exit 2
fi

DEST="$PROJECT/.cursor"

# A destination is safe to (re-)link when it does not exist yet, or when it
# is already a symlink pointing at exactly the target this run would create
# (the idempotent case). Anything else — a real file, a directory, or a
# symlink pointing somewhere else (including a broken symlink, which counts
# as "somewhere else" too) — is left alone; this installer only ever
# replaces links it could itself have produced.
check_link() { # <target> <linkname>
  if [ -L "$2" ]; then
    local current
    current="$(readlink "$2")"
    if [ "$current" = "$1" ]; then
      return 0
    fi
    printf 'refusing to replace symlink pointing elsewhere: %s\n  currently -> %s\n  would point -> %s\n' \
      "$2" "$current" "$1" >&2
    return 1
  fi
  if [ -e "$2" ]; then
    echo "refusing to replace existing file: $2" >&2
    return 1
  fi
  return 0
}

# Build the full link plan before touching anything, so a conflict on any
# one destination aborts before any destination is changed — never a
# half-installed tree.
TARGETS=("$SRC/core")
LINKS=("$DEST/agent-pipeline/core")
for f in "$SRC/adapters/$HARNESS/agents/"*.md; do
  TARGETS+=("$f"); LINKS+=("$DEST/agents/$(basename "$f")")
done
for f in "$SRC/adapters/$HARNESS/commands/"*.md; do
  TARGETS+=("$f"); LINKS+=("$DEST/commands/$(basename "$f")")
done

rc=0
for i in "${!LINKS[@]}"; do
  check_link "${TARGETS[$i]}" "${LINKS[$i]}" || rc=1
done
if [ "$rc" -ne 0 ]; then
  echo "aborting: no changes were made to $DEST" >&2
  exit 1
fi

# Only now create the destination directories. Doing it before the conflict
# check above would leave three directories behind on a refusal, making the
# "no changes were made" message false — the message is what tells the user
# it is safe to re-run after resolving the conflict.
mkdir -p "$DEST/agents" "$DEST/commands" "$DEST/agent-pipeline"

for i in "${!LINKS[@]}"; do
  ln -sfn "${TARGETS[$i]}" "${LINKS[$i]}"
done

echo "Installed $HARNESS adapter into $DEST"
echo "Next: run the doctor flow in that project to verify its requirements."
