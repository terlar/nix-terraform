{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;

    supportedSystems = [
      "aarch64-linux"
      "aarch64-darwin"
      "i686-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = lib.genAttrs supportedSystems;
  in {
    lib = {
      mkNixTerraformPkgsLib = import ./pkgs-lib;
    };

    overlays.default = final: _prev: let
      pkgsLib = self.lib.mkNixTerraformPkgsLib {
        inherit lib;
        pkgs = final;
      };
    in {
      inherit (pkgsLib) writeTerraformVersions;
    };

    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      repl = pkgs.writeShellApplication {
        name = "repl";
        runtimeInputs = [pkgs.nixVersions.stable];
        text = ''
          nix repl --file repl.nix
        '';
      };
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        propagatedBuildInputs = [
          self.packages.${system}.repl
          pkgs.deadnix
          pkgs.statix
        ];
      };
    });

    checks = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      format =
        pkgs.runCommand "check-format" {
          nativeBuildInputs = [pkgs.alejandra];
        } ''
          cd ${self}
          alejandra --check .
          mkdir "$out"
        '';

      lint =
        pkgs.runCommand "check-lint" {
          nativeBuildInputs = [pkgs.deadnix pkgs.statix];
        } ''
          cd ${self}
          deadnix --fail .
          statix check .
          mkdir "$out"
        '';
    });
  };
}
