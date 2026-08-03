#!/usr/bin/env bash
# Files under core/ must not name a harness, a harness variable, or a harness
# tool, and must not name specific third-party tooling either — a phase file
# stays usable regardless of which package manager, test runner, linter, or
# framework the consuming project happens to run underneath it.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="${1:-core}"
[ -d "$ROOT" ] || exit 0

tokens='claude|cursor|anthropic|CLAUDE_PLUGIN_ROOT|CLAUDE\.md|\bAgent tool\b|\bTask tool\b|\.cursor/'

# A sampling of common third-party tool names across ecosystems — package
# managers, test runners, linters/formatters, build tools, ORMs, and web
# frameworks — chosen to catch a careless concrete example landing in a
# core file, not to exhaustively enumerate every tool that exists. Each
# entry is word-bounded so it only matches the tool name itself, never as
# a substring of an unrelated word. Treat this as a sample, not a complete
# gate: it will miss tools it doesn't know about. Grow it only when a real
# instance slips through and is found some other way — padding it
# preemptively buys no real coverage and just makes the list slower to read.
tools='\bnpm\b|\byarn\b|\bpnpm\b|\bpip\b|\bpoetry\b|\bcargo\b|\bcomposer\b|\bbundler\b|\bnuget\b|\bmaven\b|\bgradle\b|\bpytest\b|\bjest\b|\bmocha\b|\brspec\b|\bjunit\b|\bvitest\b|\beslint\b|\bprettier\b|\bruff\b|\bflake8\b|\bpylint\b|\brubocop\b|\bwebpack\b|\bvite\b|\brollup\b|\bgulp\b|\bgrunt\b|\bbazel\b|\bsqlalchemy\b|\bhibernate\b|\bprisma\b|\bsequelize\b|\bdjango\b|\bflask\b|\brails\b|\blaravel\b|\bspring\b|\bexpress\b|\bfastapi\b|\bnestjs\b'

rc=0
while IFS= read -r f; do
  if grep -nEiI "$tokens" "$f" >/tmp/ap-neutral 2>/dev/null; then
    printf 'harness token in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-neutral; rc=1
  fi
  if grep -nEiI "$tools" "$f" >/tmp/ap-neutral-tool 2>/dev/null; then
    printf 'third-party tool name in %s:\n' "$f"; sed 's/^/  /' /tmp/ap-neutral-tool; rc=1
  fi
done < <(find "$ROOT" -type f -name '*.md')
exit $rc
