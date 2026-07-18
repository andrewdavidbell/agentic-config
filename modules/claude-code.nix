# Home Manager module: declaratively manage Claude Code via the native
# `programs.claude-code` and `programs.mcp` modules (home-manager >= 26.05).
#
# Import this from your home configuration:
#   imports = [ inputs.agentic-config.homeManagerModules.default ];
#
# What it manages (all under ~/.claude, read-only symlinks into the nix store):
#   - CLAUDE.md      via `context`
#   - skills/tdd/    via `skills.tdd`
#   - agents/*.md    via `agentsDir`
#   - hooks/tdd-guard via `hooks.tdd-guard`
#   - statusline-command.sh via `home.file`
#   - the `claude` binary (nix-provided, MCP servers injected)
#
# What it deliberately does NOT manage:
#   - settings.json — left writable so `/model` and other in-app edits persist.
#     A canonical copy lives in ../config/settings.json for reference only.
{ config, lib, pkgs, ... }:
{
  programs.claude-code = {
    enable = true;

    # Nix-provided CLI (unfree). Required for MCP injection below. Updates now
    # track nixpkgs (rebuild required) rather than the Homebrew cask.
    package = pkgs.claude-code;

    # Merge programs.mcp.servers into the wrapped `claude` binary (--plugin-dir).
    enableMcpIntegration = true;

    # Global instructions -> ~/.claude/CLAUDE.md
    context = ../config/CLAUDE.md;

    # Skills -> ~/.claude/skills/<name>/ (recursive). Other skills already in
    # ~/.claude/skills (e.g. extract-wisdom) are left untouched.
    skills.tdd = ../skills/tdd;
    skills.design-patterns = ../skills/design-patterns;

    # Subagents -> ~/.claude/agents/{tdd-red,tdd-green,tdd-refactor}.md
    agentsDir = ../agents;

    # TDD phase-boundary guard -> executable ~/.claude/hooks/tdd-guard.
    # The tdd subagents reference it by absolute path in their PreToolUse hooks.
    hooks.tdd-guard = builtins.readFile ../scripts/tdd-guard.sh;

    # NOTE: `settings` intentionally unset -> the module does not write
    # ~/.claude/settings.json, so the live file stays writable.
  };

  programs.mcp = {
    enable = true;
    servers = {
      # Docker MCP gateway (aggregates MCP servers configured in Docker Desktop).
      MCP_DOCKER = {
        command = "docker";
        args = [ "mcp" "gateway" "run" ];
      };
      # NixOS/nixpkgs/home-manager/darwin query server. `uvx` comes from
      # programs.uv (already enabled in your home config).
      nixos = {
        command = "uvx";
        args = [ "mcp-nixos" ];
      };
    };
  };

  # The status line script is static (Claude never rewrites it), so a read-only
  # symlink is safe. The unmanaged settings.json references it by absolute
  # ~/.claude path, which resolves to this symlink.
  home.file.".claude/statusline-command.sh" = {
    source = ../config/statusline-command.sh;
    executable = true;
  };
}
