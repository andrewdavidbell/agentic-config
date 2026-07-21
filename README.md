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
| `skills/design-patterns/` | `~/.claude/skills/design-patterns/` | `programs.claude-code.skills.design-patterns` |
| `agents/*.md` | `~/.claude/agents/` | `programs.claude-code.agentsDir` |
| `scripts/tdd-guard.sh` | `~/.claude/hooks/tdd-guard` (exec) | `programs.claude-code.hooks.tdd-guard` |
| `config/statusline-command.sh` | `~/.claude/statusline-command.sh` | `home.file` |
| settings (permissions, sandbox, effort, statusline) | `~/.claude/settings.json` | `programs.claude-code.settings` |
| MCP servers (`MCP_DOCKER`, `nixos`) | wrapped `claude` binary + `~/.config/mcp/mcp.json` | `programs.mcp.servers` + `enableMcpIntegration` |
| LM Studio provider env | `claude-lmstudio` launcher on `$PATH` | `writeShellScriptBin` in `modules/claude-code.nix` |

The `settings` attrset in `modules/claude-code.nix` is the single source of
truth — there is no separate `settings.json` file to keep in sync.

### Managed `settings.json`

`settings.json` is deployed as a read-only symlink into the Nix store. The one
trade-off is that in-app `/model` changes no longer persist across sessions;
model selection is pinned declaratively (`settings.model`) instead. This is a
deliberate choice — interactive model switching isn't needed here, and
everything else that changes at runtime lives in **writable** files that the
managed symlink doesn't touch:

- **permission approvals** (`/allow`) → `~/.claude/settings.local.json`
  (git-ignored)
- **onboarding / history / MCP-trust state** → `~/.claude.json`

On the first rebuild after switching to managed settings, an existing writable
`~/.claude/settings.json` is moved aside to `settings.json.backup` by Home
Manager's `backupFileExtension` rather than causing an activation conflict.

### Providers (LM Studio, …)

A non-Anthropic provider is just a set of environment overrides
(`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, the `ANTHROPIC_*_MODEL` set), so
each one is a thin launcher rather than a separate settings file. The module
generates a `claude-<name>` binary per entry in `providerEnvs` that exports the
env and execs the MCP-wrapped `claude`:

```sh
claude            # Anthropic (default)
claude-lmstudio   # local LM Studio server on 127.0.0.1:1234
```

Add a provider by extending `providerEnvs` in `modules/claude-code.nix`.

## Skills

- **tdd** — a `/tdd` orchestrator running strict Red → Green → Refactor cycles
  with git checkpoints, delegating to the `tdd-red`, `tdd-green`, and
  `tdd-refactor` subagents. A `tdd-guard` hook enforces the test/src boundary
  per phase. The guard's `is_test_path` patterns may need tuning per project
  layout (see `scripts/tdd-guard.sh`).
- **design-patterns** — a decision guide for selecting, applying, and explaining
  software design patterns (GoF creational/structural/behavioral plus
  architectural patterns and SOLID/DRY/KISS/YAGNI), with per-category reference
  files under `references/`. Emphasises *not* applying patterns when they aren't
  needed.

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

