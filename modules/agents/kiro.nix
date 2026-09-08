# Home Manager module: Kiro (AWS's agentic IDE) wiring.
#
# Enable from your home config:
#
#   programs.agenticConfig.agents.kiro.enable = true;
#
# What it manages:
#   ~/.kiro/settings/mcp.json   the shared MCP server list
#   ~/.kiro/skills/<name>/      the bespoke skills from ../../skills
#
# Kiro reads the same `{ mcpServers = { … }; }` shape as Claude Code, so this
# renders ../mcp.nix's `claudeShape` verbatim -- no per-agent translation.
# Kiro adopted the Agent Skills standard (SKILL.md) in February 2026, so the
# skill directories are linked in unmodified.
#
# NO BUILD-TIME GUARD IS POSSIBLE HERE. Kiro ships as a Homebrew cask
# (`darwinConfigurations/<host>.nix` in the consuming flake), which
# home-manager cannot see at evaluation time. Unlike the opencode module,
# this one cannot assert that the binary exists -- enabling it on a machine
# without the cask silently lays down config Kiro will never read.
#
# Read-only trade-off: ~/.kiro/settings/mcp.json is a store symlink, so
# Kiro's MCP panel cannot toggle servers on or off (those toggles write this
# file). Kiro's own precedence order -- agent config > workspace
# .kiro/settings/mcp.json > global -- provides the writable override slot;
# use a per-project workspace file rather than editing the managed global.
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agenticConfig;

  skillNames =
    builtins.attrNames
      (lib.filterAttrs (_: t: t == "directory")
        (builtins.readDir cfg.skills.path));

  skillLinks = lib.listToAttrs (map (name: {
    name = ".kiro/skills/${name}";
    value.source = cfg.skills.path + "/${name}";
  }) skillNames);
in
{
  options.programs.agenticConfig.agents.kiro = {
    enable = lib.mkEnableOption "Kiro wiring (~/.kiro MCP servers and skills)";

    linkSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Link the bespoke skills into ~/.kiro/skills/. Turn off to give Kiro
        the shared MCP servers without the shared skills.
      '';
    };
  };

  config = lib.mkIf cfg.agents.kiro.enable {
    home.file = lib.mkMerge [
      {
        ".kiro/settings/mcp.json".source =
          pkgs.writeText "kiro-mcp.json"
            (builtins.toJSON cfg.mcp.claudeShape);
      }
      (lib.mkIf cfg.agents.kiro.linkSkills skillLinks)
    ];
  };
}
