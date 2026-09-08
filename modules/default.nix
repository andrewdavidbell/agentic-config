# Home Manager module: neutral entrypoint for every agent this flake wires.
#
# Import once, then declare only which agents the machine actually runs:
#
#   imports = [ inputs.agentic-config.homeManagerModules.default ];
#
#   programs.agenticConfig = {
#     skills.enable          = true;   # publish ~/.agents/skills/
#     agents.claude.enable   = true;
#     agents.opencode.enable = true;
#     agents.kiro.enable     = true;
#   };
#
# Division of responsibility: this flake owns agent *configuration* (MCP
# server lists, skills, subagents, slash commands, baseline config files).
# It deliberately does not own agent *packages* -- those stay in the
# machine's own home config, because package version pinning is a
# machine-level concern and some agents (Kiro) are Homebrew casks that
# home-manager cannot install at all. Agent modules assert on the missing
# binary where they can, so the mismatch fails at build time.
#
# Every agent is off by default; nothing is wired until a machine opts in.
{ lib, ... }:
{
  imports = [
    ./mcp.nix
    ./skills.nix
    ./agents/claude-code.nix
    ./agents/opencode.nix
    ./agents/kiro.nix
  ];

  # The shared MCP writer is inert until an agent module consumes a shape,
  # so it is safe to leave on; individual agents gate their own output.
  programs.agenticConfig.mcp.enable = lib.mkDefault true;
}
