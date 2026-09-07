# Home Manager module: Opencode wiring for skills that need per-agent
# subagents, slash commands, or plugins beyond the shared skill
# auto-discovery provided by ../modules/skills.nix.
#
# Currently ships the TDD skill's Opencode surface:
#   ~/.config/opencode/agents/tdd-{red,green,refactor}.md  (subagent files)
#   ~/.config/opencode/commands/tdd.md                     (/tdd slash command)
#   ~/.config/opencode/plugin/tdd-guard.ts                 (phase-guard plugin)
#
# Role bodies are read from skills/tdd/references/roles/*.md (single source
# of truth, shared with the Claude Code wiring in ./claude-code.nix). The
# command body is derived from skills/tdd/SKILL.md by stripping its skill
# frontmatter and re-wrapping with Opencode command frontmatter.
#
# Enable from your home config:
#
#   programs.agenticConfig.opencode.tdd.enable = true;
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agenticConfig.opencode;

  # Body-after-frontmatter of a markdown file. Assumes standard YAML
  # frontmatter fenced by lines containing only "---". Strips the single
  # leading newline that follows the closing "---" so the caller can add
  # its own blank line without producing a double.
  bodyOf = path:
    let
      full = builtins.readFile path;
      afterOpener = lib.removePrefix "---\n" full;
      parts = lib.splitString "\n---\n" afterOpener;
      raw =
        if builtins.length parts >= 2
        then lib.concatStringsSep "\n---\n" (lib.tail parts)
        else full;
    in
      lib.removePrefix "\n" raw;

  roleBody = name:
    builtins.readFile (cfg.tdd.skillPath + "/references/roles/${name}.md");

  mkAgent = name: pkgs.writeText "tdd-${name}.md" ''
    ---
    description: "${roles.${name}.description}"
    mode: subagent
    model: ${cfg.tdd.model}
    permission:
      edit: allow
      bash: allow
    ---

    ${roleBody name}'';

  mkCommand = pkgs.writeText "tdd.md" ''
    ---
    description: Run Red-Green-Refactor TDD cycles for a feature.
    ---

    ${bodyOf (cfg.tdd.skillPath + "/SKILL.md")}'';

  roles = import ../data/tdd-roles.nix;
in
{
  options.programs.agenticConfig.opencode = {
    tdd = {
      enable = lib.mkEnableOption "TDD sub-agent files, /tdd slash command, and phase-guard plugin for Opencode";

      skillPath = lib.mkOption {
        type = lib.types.path;
        default = ../skills/tdd;
        defaultText = lib.literalExpression "${toString ../skills/tdd}";
        description = ''
          Path to the tdd skill directory. Must contain SKILL.md,
          references/roles/*.md, and assets/opencode-tdd-guard.ts.
        '';
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "anthropic/claude-sonnet-4-5";
        description = "Opencode model spec used by all three TDD sub-agents.";
      };
    };
  };

  config = lib.mkIf cfg.tdd.enable {
    home.file = {
      ".config/opencode/agents/tdd-red.md".source = mkAgent "red";
      ".config/opencode/agents/tdd-green.md".source = mkAgent "green";
      ".config/opencode/agents/tdd-refactor.md".source = mkAgent "refactor";
      ".config/opencode/commands/tdd.md".source = mkCommand;
      ".config/opencode/plugin/tdd-guard.ts".source =
        cfg.tdd.skillPath + "/assets/opencode-tdd-guard.ts";
    };
  };
}
