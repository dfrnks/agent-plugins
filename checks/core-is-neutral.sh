#!/usr/bin/env bash
# Files under core/ must not name a harness, a harness variable, or a harness
# tool, and must not name specific third-party tooling either — a phase file
# stays usable regardless of which package manager, test runner, linter, or
# framework the consuming project happens to run underneath it.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
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
#
# Deliberately absent: tool names that are also ordinary English words —
# express, spring, rails, cargo, maven, grunt, bundler, pip. Matching is
# case-insensitive and core/ is English prose, so each of those flags
# sentences like "express the rule as an imperative" as a leak. A gate that
# fires on correct prose gets disabled or worked around, which costs more
# coverage than the handful of tool names it was buying: this list is
# explicitly a sample, and dropping a name only means this gate is not the
# thing that catches it.
tools='\bnpm\b|\byarn\b|\bpnpm\b|\bpoetry\b|\bcomposer\b|\bnuget\b|\bgradle\b|\bpytest\b|\bjest\b|\bmocha\b|\brspec\b|\bjunit\b|\bvitest\b|\beslint\b|\bprettier\b|\bruff\b|\bflake8\b|\bpylint\b|\brubocop\b|\bwebpack\b|\brollup\b|\bbazel\b|\bsqlalchemy\b|\bhibernate\b|\bprisma\b|\bsequelize\b|\bdjango\b|\bflask\b|\blaravel\b|\bfastapi\b|\bnestjs\b'

# Scratch files go under a per-run mktemp directory, not a fixed /tmp path:
# a fixed name collides when two runs overlap (a developer and a hook, or two
# checkouts) and is a symlink-attack target on a shared /tmp.
#
# Stop if it cannot be created. This script does not set -e, so an unchecked
# failure would leave SCRATCH empty and every redirection below would target
# an absolute path at the filesystem root: those writes fail, grep's exit
# status is read anyway, and the gate reports clean without having examined
# anything. A checker that passes because it could not run is worse than one
# that fails.
SCRATCH="$(mktemp -d)" || { echo "cannot create a scratch directory" >&2; exit 2; }
trap 'rm -rf "$SCRATCH"' EXIT

rc=0
while IFS= read -r f; do
  if grep -nEiI "$tokens" "$f" >"$SCRATCH/tokens" 2>/dev/null; then
    printf 'harness token in %s:\n' "$f"; sed 's/^/  /' "$SCRATCH/tokens"; rc=1
  fi
  if grep -nEiI "$tools" "$f" >"$SCRATCH/tools" 2>/dev/null; then
    printf 'third-party tool name in %s:\n' "$f"; sed 's/^/  /' "$SCRATCH/tools"; rc=1
  fi
done < <(find "$ROOT" -type f -name '*.md')
exit $rc
