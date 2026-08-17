# Home Manager module: declaratively manage Claude Code via the native
# `programs.claude-code` and `programs.mcp` modules (home-manager >= 26.05).
#
# Import this from your home configuration:
#   imports = [ inputs.agentic-config.homeManagerModules.default ];
#
# What it manages (all under ~/.claude, read-only symlinks into the nix store):
#   - CLAUDE.md      via `context`
#   - settings.json  via `settings`
#   - skills/tdd/    via `skills.tdd`
#   - agents/*.md    via `agentsDir`
#   - hooks/tdd-guard via `hooks.tdd-guard`
#   - statusline-command.sh via `home.file`
#   - the `claude` binary (nix-provided, MCP servers injected -> finalPackage)
#   - the `claude-lmstudio` binary (finalPackage wrapped with LM Studio env)
#
# MCP servers are declared once in ../data/mcp-servers.nix and wired to every
# agent by modules/mcp.nix (imported below). Consumers who additionally want
# LM Studio or omlx wired should also `imports = [ … .homeManagerModules.mcp ];`
# and flip `programs.agenticConfig.mcp.forLmStudio` / `.forOmlx`.
#
# settings.json is now managed (read-only symlink into the store). The
# trade-off: in-app `/model` changes no longer persist across sessions — model
# selection is instead pinned declaratively (see `settings.model` below) or
# overridden per-provider by the wrapper binaries. Everything users actually
# mutate at runtime lives elsewhere and is unaffected: permission approvals go
# to ~/.claude/settings.local.json (writable, git-ignored), and onboarding /
# history / MCP-trust state go to ~/.claude.json (writable).
#
# Providers other than Anthropic are just environment overrides, so each is a
# thin wrapper around `finalPackage` rather than a separate settings file. Add a
# provider by extending `providerEnvs` below.
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.claude-code;

  # Per-provider environment overrides. The shared settings.json (permissions,
  # sandbox, statusline, effort) applies to every wrapper; only these env vars
  # differ. Shell env > settings.json `env`, so exporting here wins.
  providerEnvs = {
    # Local LM Studio server (OpenAI-compatible Anthropic endpoint on :1234).
    # `default_model` routes every tier to whatever model LM Studio has loaded.
    lmstudio = {
      ANTHROPIC_BASE_URL = "http://127.0.0.1:1234";
      ANTHROPIC_AUTH_TOKEN = "dummy";
      API_TIMEOUT_MS = "3000000";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      ANTHROPIC_MODEL = "default_model";
      ANTHROPIC_SMALL_FAST_MODEL = "default_model";
      ANTHROPIC_DEFAULT_HAIKU_MODEL = "default_model";
      ANTHROPIC_DEFAULT_SONNET_MODEL = "default_model";
      ANTHROPIC_DEFAULT_OPUS_MODEL = "default_model";
      CLAUDE_CODE_SUBAGENT_MODEL = "default_model";
    };
  };

  # claude-<provider>: export the provider env, then exec the MCP-wrapped claude
  # (finalPackage) so these sessions keep the same MCP servers and flags.
  mkProviderBin = name: env:
    pkgs.writeShellScriptBin "claude-${name}" ''
      ${lib.concatStringsSep "\n"
        (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") env)}
      exec ${cfg.finalPackage}/bin/claude "$@"
    '';

  providerBins = lib.mapAttrsToList mkProviderBin providerEnvs;
in
{
  imports = [
    ./mcp.nix
    ./skills.nix
  ];

  # Turn on the shared MCP writer for Claude by default; other agents opt in
  # explicitly from the consumer's home config.
  programs.agenticConfig.mcp.enable = lib.mkDefault true;
  programs.agenticConfig.mcp.forClaude = lib.mkDefault true;

  programs.claude-code = {
    enable = true;

    # Nix-provided CLI (unfree). Required for MCP injection below. Updates now
    # track nixpkgs (rebuild required) rather than the Homebrew cask.
    package = pkgs.claude-code;

    # Merge programs.mcp.servers into the wrapped `claude` binary (--plugin-dir).
    enableMcpIntegration = true;

    # Global instructions -> ~/.claude/CLAUDE.md
    context = ../config/CLAUDE.md;

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
    skills.tdd = ../skills/tdd;
    skills.design-patterns = ../skills/design-patterns;

    # Subagents -> ~/.claude/agents/{tdd-red,tdd-green,tdd-refactor}.md
    agentsDir = ../agents;

    # TDD phase-boundary guard -> executable ~/.claude/hooks/tdd-guard.
    # The tdd subagents reference it by absolute path in their PreToolUse hooks.
    hooks.tdd-guard = builtins.readFile ../scripts/tdd-guard.sh;
  };

  # MCP servers are now declared in ../data/mcp-servers.nix and wired by
  # ./mcp.nix (imported above). To add/remove per machine, override
  # `programs.agenticConfig.mcp.servers` from the consumer's home config.

  # Per-provider launcher binaries (claude-lmstudio, ...) alongside `claude`.
  home.packages = providerBins;

  # The status line script is static (Claude never rewrites it), so a read-only
  # symlink is safe. settings.json references it by absolute ~/.claude path,
  # which resolves to this symlink.
  home.file.".claude/statusline-command.sh" = {
    source = ../config/statusline-command.sh;
    executable = true;
  };
}
