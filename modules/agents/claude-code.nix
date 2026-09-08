# Home Manager module: declaratively manage Claude Code via the native
# `programs.claude-code` and `programs.mcp` modules (home-manager >= 26.05).
#
# Import this from your home configuration:
#   imports = [ inputs.agentic-config.homeManagerModules.default ];
#   programs.agenticConfig.agents.claude.enable = true;
#
# What it manages (all under ~/.claude, read-only symlinks into the nix store):
#   - CLAUDE.md      via `context`
#   - settings.json  via `settings`
#   - skills/tdd/    via `skills.tdd`
#   - agents/tdd-*.md via `agentsDir` (generated from
#     ../../skills/tdd/references/roles/*.md — single source of truth,
#     shared with ./opencode.nix)
#   - hooks/tdd-guard via `hooks.tdd-guard`
#   - statusline-command.sh via `home.file`
#   - the `claude` binary (nix-provided, MCP servers injected -> finalPackage)
#
# MCP servers are declared once in ../../data/mcp-servers.nix and wired to every
# agent by modules/mcp.nix, imported from modules/default.nix.
#
# settings.json is now managed (read-only symlink into the store). The
# trade-off: in-app `/model` changes no longer persist across sessions — model
# selection is instead pinned declaratively (see `settings.model` below).
# Everything users actually mutate at runtime lives elsewhere and is
# unaffected: permission approvals go to ~/.claude/settings.local.json
# (writable, git-ignored), and onboarding / history / MCP-trust state go to
# ~/.claude.json (writable).
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agenticConfig;

  tddRoles = import ../../data/tdd-roles.nix;
  tddSkillPath = ../../skills/tdd;

  roleBody = name:
    builtins.readFile (tddSkillPath + "/references/roles/${name}.md");

  mkClaudeAgent = name:
    let role = tddRoles.${name};
    in pkgs.writeText "tdd-${name}.md" ''
      ---
      name: tdd-${name}
      description: "${role.description}"
      tools: Read, Grep, Glob, Edit, Write, Bash
      model: inherit
      maxTurns: ${toString role.maxTurns}
      hooks:
        PreToolUse:
          - matcher: "Edit|Write"
            hooks:
              - type: command
                command: "$HOME/.claude/hooks/tdd-guard ${role.guardMode}"
      ---

      ${roleBody name}'';

  # Directory of generated subagent files, consumed by
  # programs.claude-code.agentsDir.
  tddAgentsDir = pkgs.linkFarm "tdd-agents" (map (name: {
    name = "tdd-${name}.md";
    path = mkClaudeAgent name;
  }) (builtins.attrNames tddRoles));
in
{
  options.programs.agenticConfig.agents.claude = {
    enable = lib.mkEnableOption "Claude Code wiring (~/.claude, MCP, skills)";
  };

  config = lib.mkIf cfg.agents.claude.enable {
    # Publish the shared MCP list into the wrapped `claude` binary.
    programs.agenticConfig.mcp.forClaude = lib.mkDefault true;

    programs.claude-code = {
      enable = true;

      # Nix-provided CLI (unfree). Required for MCP injection below. Updates now
      # track nixpkgs (rebuild required) rather than the Homebrew cask.
      package = pkgs.claude-code;

      # Merge programs.mcp.servers into the wrapped `claude` binary (--plugin-dir).
      enableMcpIntegration = true;

      # Global instructions -> ~/.claude/CLAUDE.md
      context = ../../config/CLAUDE.md;

      # Managed settings.json -> ~/.claude/settings.json (read-only symlink).
      # This is the single source of truth for the shared config; the module adds
      # the `$schema` key automatically. `model` is a declarative default only —
      # in-app `/model` changes won't persist (see the header note).
      settings = {
        model = "opus";
        effortLevel = "high";
        statusLine = {
          type = "command";
          command = "bash ~/.claude/statusline-command.sh";
        };
        permissions = {
          allow = [
            "Bash(git diff *)"
            "Bash(git status *)"
            "Bash(go *)"
            "Bash(cargo *)"
            "Edit(./**/*.go)"
            "Edit(./**/*.ts*)"
            "Edit(./**/*.py)"
            "WebFetch"
            "WebSearch"
          ];
          deny = [
            "Bash(sudo *)"
            "Bash(git push *)"
            "Bash(rm -rf ~*)"
            "Read(~/.ssh/**)"
            "Read(**/secrets/**)"
          ];
          ask = [
            "Bash(git add *)"
            "Bash(git commit *)"
            "Bash(rm -rf *)"
            "Bash(ssh *)"
            "Read(**/.env)"
          ];
        };
        sandbox = {
          enabled = true;
          autoAllowBashIfSandboxed = true;
          network = {
            allowedDomains = [
              "*.github.com"
              "*.githubusercontent.com"
              "*.npmjs.com"
              "*.pypi.org"
              "*.crates.io"
              "*.golang.org"
              "*.docker.io"
            ];
            allowUnixSockets = [
              "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
            ];
          };
          excludedCommands = [
            "docker"
            "ssh"
            "uv run"
            "git"
          ];
        };
      };

      # Skills -> ~/.claude/skills/<name>/ (recursive). Other skills already in
      # ~/.claude/skills (e.g. extract-wisdom) are left untouched.
      skills.tdd = ../../skills/tdd;
      skills.design-patterns = ../../skills/design-patterns;

      # Subagents -> ~/.claude/agents/{tdd-red,tdd-green,tdd-refactor}.md
      # Files are generated at Nix eval time from ../../skills/tdd/references/roles/*.md
      # + per-role metadata in ../../data/tdd-roles.nix (see the `let` block above).
      agentsDir = tddAgentsDir;

      # TDD phase-boundary guard -> executable ~/.claude/hooks/tdd-guard.
      # The tdd subagents reference it by absolute path in their PreToolUse hooks.
      hooks.tdd-guard = builtins.readFile ../../scripts/tdd-guard.sh;
    };

    # MCP servers are now declared in ../../data/mcp-servers.nix and wired by
    # ../mcp.nix (imported by ../default.nix). To add/remove per machine, override
    # `programs.agenticConfig.mcp.servers` from the consumer's home config.

    # The status line script is static (Claude never rewrites it), so a read-only
    # symlink is safe. settings.json references it by absolute ~/.claude path,
    # which resolves to this symlink.
    home.file.".claude/statusline-command.sh" = {
      source = ../../config/statusline-command.sh;
      executable = true;
    };
  };
}
