# agentic-config

My [Claude Code](https://github.com/anthropics/claude-code) configuration —
global instructions, Skills, subagents, hooks, and MCP servers — deployed
declaratively with [Home Manager](https://github.com/nix-community/home-manager)
via the native `programs.claude-code` and `programs.mcp` modules
(home-manager ≥ 26.05).

## What's here

| Path | Deployed to | How |
| --- | --- | --- |
| `config/CLAUDE.md` | `~/.claude/CLAUDE.md` | `programs.claude-code.context` |
| `skills/tdd/` | `~/.claude/skills/tdd/` | `programs.claude-code.skills.tdd` |
| `agents/*.md` | `~/.claude/agents/` | `programs.claude-code.agentsDir` |
| `scripts/tdd-guard.sh` | `~/.claude/hooks/tdd-guard` (exec) | `programs.claude-code.hooks.tdd-guard` |
| `config/statusline-command.sh` | `~/.claude/statusline-command.sh` | `home.file` |
| MCP servers (`MCP_DOCKER`, `nixos`) | wrapped `claude` binary + `~/.config/mcp/mcp.json` | `programs.mcp.servers` + `enableMcpIntegration` |
| `config/settings.json` | **not deployed** — reference copy only | — |
| `presets/lmstudio.settings.json` | **not deployed** — swap-in preset for local LM Studio | — |

### Why `settings.json` isn't deployed

Home Manager symlinks are read-only. `programs.claude-code.settings` would make
`~/.claude/settings.json` a read-only store path, so in-app changes (`/model`,
effort level, etc.) would be reverted on the next rebuild. Leaving `settings`
unset keeps the live file writable. The copy in `config/settings.json` is a
sanitised snapshot for reference/reproducibility.

To refresh the snapshot after changing settings in the app:

```sh
cp ~/.claude/settings.json config/settings.json
# then sanitise any absolute /Users/... paths to ~/ before committing
```

## Skills

- **tdd** — a `/tdd` orchestrator running strict Red → Green → Refactor cycles
  with git checkpoints, delegating to the `tdd-red`, `tdd-green`, and
  `tdd-refactor` subagents. A `tdd-guard` hook enforces the test/src boundary
  per phase. The guard's `is_test_path` patterns may need tuning per project
  layout (see `scripts/tdd-guard.sh`).

## Using it (Home Manager flake)

This repo is a flake exposing `homeManagerModules.default`. Add it to your
home configuration:

```nix
# flake.nix inputs
agentic-config.url = "github:andrewdavidbell/agentic-config";
```

```nix
# your home module
{ inputs, ... }: {
  imports = [ inputs.agentic-config.homeManagerModules.default ];
}
```

Then rebuild (nix-darwin example):

```sh
sudo darwin-rebuild switch --flake ~/.config/nix#<host>
```

The module sets `programs.claude-code.package = pkgs.claude-code` (unfree —
your config must allow unfree), so the CLI is provided by Nix and updates with
nixpkgs rather than an external package manager. The declared MCP servers are
injected into the wrapped `claude` binary automatically; verify with
`claude mcp list`.

## Not (yet) included

- **design-patterns** — a complete decision-guide skill; drop it in under
  `skills/design-patterns/` and add
  `programs.claude-code.skills.design-patterns = ../skills/design-patterns;`.
- **extract-wisdom** — builds a `.venv` inside its own skill directory at
  runtime, which a read-only store symlink forbids; it needs to stay unmanaged
  or use a writable copy rather than a naïve symlink.
