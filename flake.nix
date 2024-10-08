{
  description = "Nix+Terraform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        config,
        withSystem,
        ...
      }:
      {
        systems = [
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
          "x86_64-linux"
        ];

        imports = [ inputs.flake-parts.flakeModules.partitions ];

        partitionedAttrs = {
          checks = "dev";
          devShells = "dev";
        };

        partitions.dev = {
          extraInputsFlake = ./dev;
          module.imports = [ ./dev/flake-module.nix ];
        };

        flake = {
          lib.mkNixTerraformPkgsLib = import ./pkgs-lib;
          overlays.default =
            _final: prev: withSystem prev.stdenv.hostPlatform.system (ctx: ctx.config.legacyPackages);
        };

        perSystem =
          { pkgs, ... }:
          {
            legacyPackages = config.flake.lib.mkNixTerraformPkgsLib {
              inherit pkgs;
              terranixConfiguration = args: inputs.terranix.lib.terranixConfiguration (args // { inherit pkgs; });
            };
          };
      }
    );
}
