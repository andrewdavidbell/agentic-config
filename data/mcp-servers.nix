# Shared MCP server definitions consumed by every agent (Claude Code, opencode,
# LM Studio, omlx). Pure data — no module system, no pkgs — so external flakes
# can `import ./data/mcp-servers.nix` without pulling in home-manager.
#
# Each entry:
#   command  = executable name (looked up on PATH at server start)
#   args     = list of string arguments
#   env      = optional attrset of environment variables (defaults to {})
#
# All servers run as direct processes (npx/uvx), so this list is portable
# across machines without requiring Docker Desktop. To disable a server on a
# specific host, override `programs.agenticConfig.mcp.servers` with
# `builtins.removeAttrs … [ "name" ]` in that machine's home config.
{
  # NixOS / nixpkgs / home-manager / darwin query server.
  # `uvx` is provided by programs.uv.
  nixos = {
    command = "uvx";
    args = [ "mcp-nixos" ];
  };

  # Context7 (Upstash) — narrowed library-docs fetch by resolved library ID.
  # More targeted than blind WebFetch; no API key required.
  context7 = {
    command = "npx";
    args = [ "-y" "@upstash/context7-mcp" ];
  };

  # AWS documentation — search + structured section reads over docs.aws.amazon.com.
  # No API key required.
  aws-documentation = {
    command = "uvx";
    args = [ "awslabs.aws-documentation-mcp-server" ];
  };

  # Headroom — token-compression MCP. Requires the `headroom` CLI on PATH,
  # installed per-machine via `uv tool install "headroom-ai[all]"` (see
  # docs/headroom-setup.md in the consumer flake). Hosts without the CLI
  # will show this entry as unavailable — override with removeAttrs there.
  headroom = {
    command = "headroom";
    args = [ "mcp" "serve" ];
  };
}
