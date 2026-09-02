# Home Manager module: publish agent-agnostic Skills at the emerging
# shared discovery path ~/.agents/skills/, so tools that adopt the
# convention (OpenCode ≥ 1.15 auto-discovers; future agents likely)
# pick them up with no extra wiring. Claude Code's own skill wiring
# (~/.claude/skills/<name>/) is unchanged — it stays in
# modules/claude-code.nix via programs.claude-code.skills.*.
#
# Skills are published one entry per skill so user-created symlinks
# for third-party skills can coexist in ~/.agents/skills/ alongside
# the bespoke ones.
#
#   programs.agenticConfig.skills = {
#     enable = true;
#     # path defaults to ../skills relative to this repo
#   };
{ config, lib, ... }:
let
  cfg = config.programs.agenticConfig.skills;
  skillNames =
    builtins.attrNames
      (lib.filterAttrs (_: t: t == "directory")
        (builtins.readDir cfg.path));
in
{
  options.programs.agenticConfig.skills = {
    enable = lib.mkEnableOption "publish shared Skills to ~/.agents/skills/";

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
        (`''${config.home.homeDirectory}/.agents/skills`). OpenCode
        and other agent-agnostic harnesses read from here directly.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.listToAttrs (map (name: {
      name = ".agents/skills/${name}";
      value.source = cfg.path + "/${name}";
    }) skillNames);
    programs.agenticConfig.skills.installedPath =
      "${config.home.homeDirectory}/.agents/skills";
  };
}
