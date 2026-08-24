#!/usr/bin/env bash
# Test runner. No dependencies beyond coreutils and git.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0; FAIL=0

assert_exit() { # <expected> <description> <cmd…>
  local expected="$1" desc="$2"; shift 2
  "$@" >/tmp/ap-test-out 2>&1
  local actual=$?
  if [ "$actual" = "$expected" ]; then
    printf 'PASS  %s\n' "$desc"; PASS=$((PASS+1))
  else
    printf 'FAIL  %s (expected exit %s, got %s)\n' "$desc" "$expected" "$actual"
    sed 's/^/      /' /tmp/ap-test-out; FAIL=$((FAIL+1))
  fi
}

assert_executable() { # <path> <description>
  if [ -x "$1" ]; then printf 'PASS  %s\n' "$2"; PASS=$((PASS+1))
  else printf 'FAIL  %s (not executable: %s)\n' "$2" "$1"; FAIL=$((FAIL+1)); fi
}

assert_executable checks/structure.sh "structure checker is executable"
assert_executable checks/no-leakage.sh      "leakage checker is executable"
assert_executable checks/core-is-neutral.sh "neutrality checker is executable"
assert_executable checks/references-resolve.sh "reference checker is executable"

# Fixtures: each must be rejected by its checker.
assert_exit 1 "leakage checker rejects an absolute home path" \
  checks/no-leakage.sh tests/fixtures/leak-abs-path.md
assert_exit 1 "leakage checker rejects an email address" \
  checks/no-leakage.sh tests/fixtures/leak-email-real.md
assert_exit 0 "leakage checker accepts an allowlisted email domain" \
  checks/no-leakage.sh tests/fixtures/leak-email.md
assert_exit 0 "leakage checker accepts an allowlisted home path" \
  checks/no-leakage.sh tests/fixtures/leak-abs-path-allowlisted.md
assert_exit 1 "leakage checker rejects identifiers that merely contain allowlisted substrings" \
  checks/no-leakage.sh tests/fixtures/leak-lookalike.md
assert_exit 0 "leakage checker accepts a clean file" \
  checks/no-leakage.sh tests/fixtures/clean.md
assert_exit 0 "leakage checker passes a whole-repo scan" \
  checks/no-leakage.sh
assert_exit 1 "neutrality checker rejects a harness token in core" \
  checks/core-is-neutral.sh tests/fixtures/core-dirty
assert_exit 0 "neutrality checker accepts neutral prose" \
  checks/core-is-neutral.sh tests/fixtures/core-clean
assert_exit 1 "neutrality checker rejects a named third-party tool in core" \
  checks/core-is-neutral.sh tests/fixtures/core-tool-dirty
assert_exit 0 "neutrality checker accepts a tool token embedded in a larger word" \
  checks/core-is-neutral.sh tests/fixtures/core-tool-lookalike
assert_exit 1 "reference checker rejects a dangling core reference" \
  checks/references-resolve.sh tests/fixtures/dangling.md
assert_exit 0 "reference checker accepts a reference that resolves" \
  checks/references-resolve.sh tests/fixtures/reference-ok.md
assert_exit 0 "reference checker passes a whole-repo scan" \
  checks/references-resolve.sh
assert_exit 0 "structure checker passes when the file exists with its required heading" \
  checks/structure.sh tests/fixtures/manifest-good.txt
assert_exit 1 "structure checker rejects a missing file" \
  checks/structure.sh tests/fixtures/manifest-missing-file.txt
assert_exit 1 "structure checker rejects a file missing a required heading" \
  checks/structure.sh tests/fixtures/manifest-missing-heading.txt
assert_exit 2 "structure checker rejects a manifest path that does not exist" \
  checks/structure.sh tests/fixtures/manifest-does-not-exist.txt
assert_exit 2 "structure checker rejects a manifest path that is a directory" \
  checks/structure.sh tests/fixtures
assert_exit 2 "structure checker rejects a manifest declaring no records" \
  checks/structure.sh tests/fixtures/manifest-comments-only.txt
assert_exit 1 "structure checker enforces a last record with no trailing newline" \
  checks/structure.sh tests/fixtures/manifest-unterminated.txt
assert_exit 1 "structure checker rejects a record missing its separator" \
  checks/structure.sh tests/fixtures/manifest-no-separator.txt
assert_exit 1 "structure checker rejects a record with an empty path" \
  checks/structure.sh tests/fixtures/manifest-empty-path.txt
assert_exit 1 "structure checker rejects a headings field that names none" \
  checks/structure.sh tests/fixtures/manifest-empty-headings.txt
assert_exit 1 "structure checker rejects a heading named only in prose" \
  checks/structure.sh tests/fixtures/manifest-heading-lookalike.txt
assert_exit 0 "structure checker passes the real manifest against the repository" \
  checks/structure.sh
assert_exit 0 "every core phase and flow has a Claude Code adapter" \
  checks/adapters-cover-core.sh claude-code
assert_exit 1 "adapter-coverage checker rejects an adapter directory missing a core file" \
  checks/adapters-cover-core.sh fixture tests/fixtures/adapters-missing-coverage
assert_exit 1 "adapter-coverage checker rejects a harness with no adapter directory at all" \
  checks/adapters-cover-core.sh nonexistent-harness
assert_exit 0 "every core phase and flow has a Cursor adapter" \
  checks/adapters-cover-core.sh cursor
assert_exit 0 "installer creates cursor links in a fixture project" \
  tests/cases/install-cursor.sh

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
