---
name: tdd-red
description: <one-line summary of the role's job — see references/roles/red.md>
tools: Read, Grep, Glob, Edit, Write, Bash
model: inherit
maxTurns: 20
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "$HOME/.claude/hooks/tdd-guard tests-only"
---

<paste the full body of skills/tdd/references/roles/red.md verbatim>
