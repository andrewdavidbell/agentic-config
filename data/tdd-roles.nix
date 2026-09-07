# Shared per-role metadata used by the Claude Code and Opencode wiring
# modules. Role bodies (the system-prompt text each role runs under) live
# in ../skills/tdd/references/roles/*.md — this file only carries the
# metadata each harness needs to compose a subagent file:
#
#   description  one-line summary shown in the harness's agent picker
#   maxTurns     Claude Code turn cap for the subagent
#   guardMode    argument passed to the Claude Code tdd-guard hook
#
# Opencode's subagent frontmatter has no maxTurns; its plugin-based guard
# reads phase state from .tdd/phase instead of a mode argument. Those
# fields are simply ignored by the Opencode module.
{
  red = {
    description = "Picks the next behaviour to verify and writes ONE failing test for it. Owns the Red phase. Never writes or modifies production code. Use at the start of every TDD cycle and after each Green/Refactor completes.";
    maxTurns = 20;
    guardMode = "tests-only";
  };
  green = {
    description = "Writes the minimum production code needed to make the currently failing test pass. Owns the Green phase. Never modifies tests. Use immediately after tdd-red reports a failing test.";
    maxTurns = 25;
    guardMode = "src-only";
  };
  refactor = {
    description = "Improves the design of code that's already green by removing smells and applying patterns where justified. Owns the Refactor phase, including preparatory refactors requested by Green. Must preserve all behaviour. Use after tdd-green reports success, or when Green requests a design change.";
    maxTurns = 25;
    guardMode = "src-only";
  };
}
