---
name: tdd
description: Run Red-Green-Refactor TDD cycles for a feature, orchestrating the tdd-red, tdd-green, and tdd-refactor subagents with commit checkpoints between phases.
argument-hint: [feature description] [--cycles N]
disable-model-invocation: true
---

Run strict Red-Green-Refactor cycles for: $ARGUMENTS

If `--cycles N` is present in the arguments, run N cycles without asking
between them (still stop early on backlog exhaustion or failure). Otherwise
ask after each cycle whether to continue.

## Setup (once, before cycle 1)

1. Confirm the working tree is clean (`git status --porcelain`). If it
   isn't, ask the user whether to commit, stash, or abort. Do not start
   cycles on a dirty tree — the checkpoint/revert discipline depends on it.
2. Run the full test suite once and record the set of failing tests as the
   BASELINE (ideally empty, but pre-existing failures must not wedge the
   loop). Every later "green" judgment means "failing set equals baseline",
   not "zero failures".
3. Verify the guard hook `~/.claude/hooks/tdd-guard` exists and is
   executable (it is installed globally by home-manager). If missing, warn
   the user that phase boundaries are enforced by prompt only.

## The cycle

1. **Red.** Delegate to the `tdd-red` subagent. Include in the delegation
   message: the feature description, the BASELINE failing set, and (on
   cycles after the first) the deferred-candidates list from the previous
   Red report. Red also persists its backlog in `.tdd/backlog.md`, so a
   resumed session recovers state from there.
   If Red reports "backlog exhausted", skip to Wrap-up.
   Checkpoint: commit with message `tdd(red): <test name>`.

2. **Green.** Delegate to the `tdd-green` subagent. Include: the failing
   test's file path and name, Red's exact failure output, and the BASELINE
   failing set.
   - On success, verify independently that `git diff --name-only` since the
     Red checkpoint contains no test paths. If it does, `git restore .` and
     re-delegate with a note about the violation.
   - Checkpoint: commit `tdd(green): <test name>`.
   - **If Green stops and requests a design change instead:**
     a. Skip the new failing test using the framework's native mechanism
        (@skip / it.skip / t.Skip / #[ignore]) so the suite returns to
        baseline. Commit `tdd(park): <test name>`.
     b. Delegate to `tdd-refactor` in preparatory mode with Green's exact
        request and the file list. Commit `tdd(prep): <change>`.
     c. Un-skip the test and return to step 2. If Green requests a second
        preparatory refactor for the same test, stop and surface to the
        user — the behavior may be mis-scoped and belong back in Red.

3. **Refactor.** Delegate to the `tdd-refactor` subagent in post-Green
   mode. Include: the BASELINE failing set and the list of files changed
   this cycle (`git diff --name-only` against the cycle-start commit).
   Declining is a valid outcome, not a failure. If it made changes, verify
   the suite matches baseline, then commit `tdd(refactor): <move>`.

4. **Cycle summary.** Print one line:
   `[TDD] cycle <n>: red=<test name> | green=<tactic> | refactor=<move or 'none'>`
   Then continue per the --cycles setting, or ask the user.

## Failure handling

If at any phase the suite regresses below baseline and the responsible
subagent cannot restore it, stop the loop, leave the tree at the last good
checkpoint commit (`git restore .` any uncommitted damage), and report to
the user exactly which phase failed and why. Never silently continue past
a regression.

## Wrap-up

- Show `.tdd/backlog.md` status (done vs. remaining).
- Offer to squash the `tdd(...)` micro-commits into one feature commit if
  the user prefers a clean history; do not squash without asking.
