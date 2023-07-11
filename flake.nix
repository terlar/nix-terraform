{
  description = "Nix+Terraform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} ({
      config,
      withSystem,
      ...
    }: {
      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      flake = {
        lib.mkNixTerraformPkgsLib = import ./pkgs-lib;
        overlays.default = _final: prev:
          withSystem prev.stdenv.hostPlatform.system (ctx: ctx.config.legacyPackages);
      };

      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;

        legacyPackages = config.flake.lib.mkNixTerraformPkgsLib {inherit pkgs;};
      };
    });
}
