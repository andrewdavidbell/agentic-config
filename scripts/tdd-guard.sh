#!/bin/bash
# tdd-guard.sh — PreToolUse hook enforcing the test/src boundary per TDD phase.
#
# Installed by home-manager as an executable at ~/.claude/hooks/tdd-guard.
# Referenced from the tdd-red/green/refactor subagent frontmatter, e.g.:
#   command: "$HOME/.claude/hooks/tdd-guard tests-only"  (Red: tests + .tdd/ only)
#   command: "$HOME/.claude/hooks/tdd-guard src-only"    (Green/Refactor: not tests/.tdd/)
#
# Reads the hook JSON from stdin; exits 2 to block, 0 to allow.
# ADJUST the is_test_path patterns to match your project layout.

set -u
MODE="${1:-}"
INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
else
  # Fallback: crude extraction of "file_path":"..." (handles the common case;
  # install jq for robust parsing)
  FILE=$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi
[ -z "$FILE" ] && exit 0   # not a file write we can classify; allow

# Normalize to repo-relative-ish path for matching
case "$FILE" in
  *"/.tdd/"*|.tdd/*)  IS_TDD_DIR=1 ;;
  *)                  IS_TDD_DIR=0 ;;
esac

is_test_path() {
  case "$1" in
    tests/*|test/*|__tests__/*|spec/*) return 0 ;;                 # at repo root
    */tests/*|*/test/*|*/__tests__/*|*/spec/*) return 0 ;;         # nested
    *_test.*|*.test.*|*.spec.*|*_spec.*) return 0 ;;               # file suffixes
    test_*.py|*/test_*.py) return 0 ;;                             # pytest prefix
    conftest.py|*/conftest.py) return 0 ;;
    *) return 1 ;;
  esac
}

if is_test_path "$FILE"; then IS_TEST=1; else IS_TEST=0; fi

case "$MODE" in
  tests-only)
    # Red: allow test files and the .tdd/ backlog directory, block everything else
    if [ "$IS_TEST" = "0" ] && [ "$IS_TDD_DIR" = "0" ]; then
      echo "Blocked by tdd-guard: the Red phase may only modify test files and .tdd/. Attempted: $FILE" >&2
      exit 2
    fi
    ;;
  src-only)
    # Green/Refactor: block test files and the .tdd/ directory
    if [ "$IS_TEST" = "1" ] || [ "$IS_TDD_DIR" = "1" ]; then
      echo "Blocked by tdd-guard: this phase may not modify test files or .tdd/. Attempted: $FILE. If the test is wrong, report it — do not fix it." >&2
      exit 2
    fi
    ;;
  *)
    echo "tdd-guard: unknown mode '$MODE' (expected tests-only|src-only); allowing." >&2
    ;;
esac

exit 0
