# Home Manager module: publish agent-agnostic Skills at a shared,
# discoverable location so any tool that reads instruction files
# (opencode via AGENTS.md, future agents) can reference them.
#
# Claude Code's own skill wiring (~/.claude/skills/<name>/) is unchanged —
# it stays in modules/claude-code.nix via programs.claude-code.skills.*.
# This module only exposes the shared subtree.
#
#   programs.agenticConfig.skills = {
#     enable = true;
#     # path defaults to ../skills relative to this repo
#   };
#
# Result: ~/.local/share/agentic-skills/ → read-only symlink into the
# nix store containing tdd/, design-patterns/, etc.
{ config, lib, ... }:
let
  cfg = config.programs.agenticConfig.skills;
in
{
  options.programs.agenticConfig.skills = {
    enable = lib.mkEnableOption "publish shared Skills to xdg.dataHome/agentic-skills";

    path = lib.mkOption {
      type = lib.types.path;
      default = ../skills;
      defaultText = lib.literalExpression "${toString ../skills}";
      description = "Source directory containing SKILL.md subdirectories.";
    };

    installedPath = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Resolved absolute path where skills are installed
        (`''${xdg.dataHome}/agentic-skills`). Reference this from
        agent-specific AGENTS.md files to point tools at the subtree.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.dataFile."agentic-skills".source = cfg.path;
    programs.agenticConfig.skills.installedPath =
      "${config.xdg.dataHome}/agentic-skills";
  };
}
