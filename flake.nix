{
  description = "Andrew's Claude Code / agentic assistant configuration";

  # No inputs: the module is pure and references the consuming home-manager
  # evaluation's `pkgs` (your nixpkgs-26.05-darwin), avoiding version skew.
  outputs = { self }: {
    homeManagerModules.default = import ./modules/claude-code.nix;
    homeManagerModules.claude-code = self.homeManagerModules.default;
  };
}
