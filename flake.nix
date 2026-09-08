{
  description = "Andrew's agentic assistant configuration (Claude Code, Opencode, Kiro)";

  # No inputs: modules are pure and reference the consuming home-manager
  # evaluation's `pkgs` (your nixpkgs-26.05-darwin), avoiding version skew.
  outputs = { self }: {
    # Neutral entrypoint: imports the shared MCP + skills modules and every
    # agent module, all of which stay inert until the consumer opts in with
    # `programs.agenticConfig.agents.<name>.enable = true`.
    homeManagerModules.default = import ./modules/default.nix;

    # Standalone modules, for consumers that want one piece without the rest.
    # Note these do NOT pull in mcp.nix/skills.nix the way `default` does --
    # importing an agent module alone means wiring its dependencies yourself.
    homeManagerModules.mcp = import ./modules/mcp.nix;
    homeManagerModules.skills = import ./modules/skills.nix;
    homeManagerModules.claude-code = import ./modules/agents/claude-code.nix;
    homeManagerModules.opencode = import ./modules/agents/opencode.nix;
    homeManagerModules.kiro = import ./modules/agents/kiro.nix;

    # Raw data — importable without the module system, so external flakes can
    # compose these into their own configs.
    lib.mcpServers = import ./data/mcp-servers.nix;
    lib.skillsPath = ./skills;
  };
}
