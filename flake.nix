{
  description = "Andrew's Claude Code / agentic assistant configuration";

  # No inputs: modules are pure and reference the consuming home-manager
  # evaluation's `pkgs` (your nixpkgs-26.05-darwin), avoiding version skew.
  outputs = { self }: {
    # Full Claude Code wiring (also transitively imports mcp + skills modules).
    homeManagerModules.default = import ./modules/claude-code.nix;
    homeManagerModules.claude-code = self.homeManagerModules.default;

    # Standalone agent-agnostic modules for consumers that only need
    # MCP or Skills wired without pulling the Claude-specific config.
    homeManagerModules.mcp = import ./modules/mcp.nix;
    homeManagerModules.skills = import ./modules/skills.nix;

    # Raw data — importable without the module system, so external flakes can
    # compose these into their own configs (e.g. rendering opencode.jsonc).
    lib.mcpServers = import ./data/mcp-servers.nix;
    lib.skillsPath = ./skills;
  };
}
