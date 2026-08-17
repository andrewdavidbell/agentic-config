# Home Manager module: agent-agnostic MCP wiring.
#
# Given a single attrset of MCP server definitions (see ../data/mcp-servers.nix
# for the shape), this writes each participating agent's native MCP config file
# and exposes a computed opencode-shaped fragment that callers merge into their
# own opencode.jsonc.
#
# Enable it and pick which agents to wire:
#
#   programs.agenticConfig.mcp = {
#     enable = true;
#     forClaude    = true;   # feeds programs.mcp -> claude wrapper
#     forLmStudio  = true;   # writes ~/.cache/lm-studio/mcp.json
#     # opencode is wired by consumers merging `opencodeConfig` into their config
#     # servers = <override> // { … };  # optional
#   };
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agenticConfig.mcp;

  # Claude-shape (also what LM Studio and omlx accept):
  # { mcpServers = { <name> = { command, args, env? }; ... }; }
  claudeShape = {
    mcpServers = lib.mapAttrs (_: srv:
      { inherit (srv) command args; }
      // lib.optionalAttrs (srv ? env) { inherit (srv) env; }
    ) cfg.servers;
  };

  # Opencode-shape: { mcp = { <name> = { type="local"; command=[cmd] ++ args;
  #                                       enabled=true; environment=env; }; }; }
  opencodeShape = lib.mapAttrs (_: srv: (
    {
      type = "local";
      command = [ srv.command ] ++ srv.args;
      enabled = true;
    }
    // lib.optionalAttrs (srv ? env) { environment = srv.env; }
  )) cfg.servers;

  serverAttrType = lib.types.submodule {
    options = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Executable name (looked up on PATH when the server starts).";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments passed to the command.";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables set for the server process.";
      };
    };
  };
in
{
  options.programs.agenticConfig.mcp = {
    enable = lib.mkEnableOption "agent-agnostic MCP wiring";

    servers = lib.mkOption {
      type = lib.types.attrsOf serverAttrType;
      default = import ../data/mcp-servers.nix;
      defaultText = lib.literalExpression "import ${toString ../data/mcp-servers.nix}";
      description = ''
        MCP servers to publish to every enabled agent. Defaults to the
        shared list in `data/mcp-servers.nix`; override per-machine to
        add, remove (e.g. `builtins.removeAttrs … [ "MCP_DOCKER" ]`),
        or swap entries.
      '';
    };

    forClaude = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Feed `programs.mcp.servers` so Claude Code's wrapper picks these up.";
    };

    forLmStudio = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Manage ~/.cache/lm-studio/mcp.json (read-only symlink into the nix store).";
    };

    opencodeConfig = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = ''
        Computed opencode-shaped MCP fragment. Merge into your
        opencode.jsonc under the top-level `mcp` key.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.agenticConfig.mcp.opencodeConfig = opencodeShape;

    programs.mcp = lib.mkIf cfg.forClaude {
      enable = true;
      servers = cfg.servers;
    };

    home.file.".cache/lm-studio/mcp.json" = lib.mkIf cfg.forLmStudio {
      source = pkgs.writeText "lm-studio-mcp.json"
        (builtins.toJSON claudeShape);
    };
  };
}
