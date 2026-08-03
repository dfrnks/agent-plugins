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

Install it instead via Claude Code's plugin flow, e.g.:
  claude plugin marketplace add <path-or-url-to-this-repository>
  claude plugin install tdd-pipeline
EOF
  exit 2
fi

DEST="$PROJECT/.cursor"

link() { # <target> <linkname>
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    echo "refusing to replace existing file: $2" >&2; exit 1
  fi
  ln -sfn "$1" "$2"
}

mkdir -p "$DEST/agents" "$DEST/commands" "$DEST/agent-pipeline"
link "$SRC/core" "$DEST/agent-pipeline/core"
for f in "$SRC/adapters/$HARNESS/agents/"*.md;   do link "$f" "$DEST/agents/$(basename "$f")"; done
for f in "$SRC/adapters/$HARNESS/commands/"*.md; do link "$f" "$DEST/commands/$(basename "$f")"; done

echo "Installed $HARNESS adapter into $DEST"
echo "Next: run the doctor flow in that project to verify its requirements."
