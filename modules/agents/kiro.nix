# Home Manager module: Kiro (AWS's agentic IDE) wiring.
#
# Enable from your home config:
#
#   programs.agenticConfig.agents.kiro.enable = true;
#
# What it manages:
#   ~/.kiro/settings/mcp.json.nix-baseline   authoritative copy of the shared list
#   ~/.kiro/settings/mcp.json                SEEDED ONCE, then yours to edit
#   ~/.kiro/skills/<name>/                   the bespoke skills from ../../skills
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
# == Why mcp.json is seeded rather than symlinked ==
#
# It used to be `home.file."…/mcp.json".source`, i.e. a read-only store
# symlink, on the theory that Kiro's precedence order (agent config >
# workspace `.kiro/settings/mcp.json` > global) supplied the writable
# override slot. That theory does not survive contact with a multi-root
# workspace: with more than one repo open, the workspace-level file is not
# honoured, so there is no usable override and the read-only global is the
# only thing in play. Kiro's MCP panel writes this file to toggle, add or
# delete a server, so a store symlink makes all three fail.
#
# So the file is now seeded from the shared list on first activation and
# left alone forever after -- a real, writable file that Kiro fully owns.
# Same shape as ./opencode.nix's `local.jsonc` overlay, except Kiro's config
# format has no `include` directive, so the baseline cannot be layered
# under a user file; seeding the user file is the closest equivalent.
#
# The cost is drift: once seeded, later changes to ../../data/mcp-servers.nix
# never reach this machine. That is why nix also writes an authoritative
# `mcp.json.nix-baseline` next to it -- a path Kiro does not read -- so the
# drift is diffable instead of silent:
#
#   diff ~/.kiro/settings/mcp.json{,.nix-baseline}
#
# Both files are pretty-printed via pkgs.formats.json (NOT builtins.toJSON,
# whose single-line output would make that diff useless) for the same
# reason: one is meant to be hand-edited, the other to be read by eye.
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agenticConfig;

  # Pretty-printed, so the baseline diff above is line-granular and the
  # seeded file is pleasant to hand-edit.
  mcpBaseline =
    (pkgs.formats.json { }).generate "kiro-mcp.json" cfg.mcp.claudeShape;

  mcpPath = "${config.home.homeDirectory}/.kiro/settings/mcp.json";

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

    seedMcp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Seed ~/.kiro/settings/mcp.json from the shared server list on first
        activation, and write an authoritative
        ~/.kiro/settings/mcp.json.nix-baseline to diff against later. The
        seeded file is writable and never overwritten again, so Kiro's MCP
        panel can toggle, add and delete servers normally.

        Turn off to leave the file entirely to Kiro, in which case nothing
        here touches it and a fresh machine starts with no shared servers.
      '';
    };
  };

  config = lib.mkIf cfg.agents.kiro.enable {
    home.file = lib.mkMerge [
      # Read-only reference copy. Kiro reads `mcp.json`, not this, so it is
      # inert config-wise -- it exists purely as the drift oracle.
      (lib.mkIf cfg.agents.kiro.seedMcp {
        ".kiro/settings/mcp.json.nix-baseline".source = mcpBaseline;
      })
      (lib.mkIf cfg.agents.kiro.linkSkills skillLinks)
    ];

    # entryAfter "linkGeneration", NOT "writeBoundary": on the first
    # activation after the symlink-era generation, the old read-only
    # mcp.json symlink is still present until linkGeneration removes it.
    # Seeding before that point would find the path occupied, skip, and
    # leave no file at all once the unlink happened.
    home.activation.kiroMcpSeed = lib.mkIf cfg.agents.kiro.seedMcp (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        mcp="${mcpPath}"

        # Defensive: clear a leftover store symlink even if the ordering
        # above is ever disturbed. Without this, the install below would
        # follow a dangling link and try to write into /nix/store.
        if [ -L "$mcp" ]; then
          case "$(readlink "$mcp")" in
            /nix/store/*) $DRY_RUN_CMD rm -f $VERBOSE_ARG "$mcp" ;;
          esac
        fi

        if [ ! -e "$mcp" ]; then
          $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$(dirname "$mcp")"
          # install -m, not cp: cp would carry the store's read-only 0444.
          $DRY_RUN_CMD install -m 0644 ${mcpBaseline} "$mcp"
        fi
      ''
    );
  };
}
