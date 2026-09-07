# The phase guard

The guard is a pre-write hook that blocks file writes violating the current
phase's boundary. It exists to make TDD discipline mechanical rather than
prompt-only.

## What each phase allows

| Phase    | May write to           | May NOT write to        |
| -------- | ---------------------- | ----------------------- |
| Red      | tests, `.tdd/`         | production source       |
| Green    | production source      | tests, `.tdd/`          |
| Refactor | production source      | tests, `.tdd/`          |

"Tests" means the harness-detected test file patterns: `tests/`, `test/`,
`__tests__/`, `spec/` (at any depth), and file suffixes `_test.*`,
`.test.*`, `.spec.*`, `_spec.*`, plus Python's `test_*.py` and
`conftest.py`. Adjust for the project's actual layout.

## Why it exists

Without the guard, the boundary is a rule in prose. Green's most common
failure mode is "helpfully" editing a failing test to make it pass;
Refactor's is "while I'm here" scope creep into new behaviour. Both are
caught silently by prompt discipline and loudly by the guard.

## Per-harness implementation

- Claude Code: shell script invoked as a `PreToolUse` hook — see
  `wiring/claude-code.md`.
- Opencode: TypeScript plugin listening on `tool.execute.before` — see
  `wiring/opencode.md`.

The contract is the same in both: on an out-of-phase write, block the tool
call with a message naming the phase, the attempted path, and (for
Green/Refactor) the instruction "if the test is wrong, report it — do not
fix it".

## No-guard degradation

If the harness cannot enforce the boundary (no hook mechanism, or the
plugin isn't installed), the workflow still runs — the role prompts
contain "hard rules" that describe the same boundary. Warn the user at
setup that phase boundaries are prompt-enforced only. Expect occasional
crossings; catch them in review of the per-cycle commits.
