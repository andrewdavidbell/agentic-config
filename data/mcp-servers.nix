# Shared MCP server definitions consumed by every agent (Claude Code, opencode,
# LM Studio, omlx). Pure data — no module system, no pkgs — so external flakes
# can `import ./data/mcp-servers.nix` without pulling in home-manager.
#
# Each entry:
#   command  = executable name (looked up on PATH at server start)
#   args     = list of string arguments
#   env      = optional attrset of environment variables (defaults to {})
#
# Machines that lack a server (e.g. Rancher-only hosts have no Docker MCP
# gateway) subtract entries via `builtins.removeAttrs …` when overriding
# `programs.agenticConfig.mcp.servers` in their home config.
{
  # Docker MCP gateway — aggregates the MCP servers enabled via
  # Docker Desktop's MCP Toolkit (see ~/.docker/mcp/registry.yaml).
  # Requires Docker Desktop; not available on Rancher-only hosts.
  MCP_DOCKER = {
    command = "docker";
    args = [ "mcp" "gateway" "run" ];
  };

  # NixOS / nixpkgs / home-manager / darwin query server.
  # `uvx` is provided by programs.uv.
  nixos = {
    command = "uvx";
    args = [ "mcp-nixos" ];
  };
}
