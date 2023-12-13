{
  description = "Development environment";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    dev-flake = {
      url = "github:terlar/dev-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # For Terraform packages pre 1.x
    nixpkgs-21_11.url = "github:nixos/nixpkgs/release-21.11";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];

      imports = [inputs.dev-flake.flakeModule];

      dev = {
        name = "terlar/nix-terraform";
        rootSrc = ../.;
      };

      perSystem = {
        pkgs,
        system,
        inputs',
        rootFlake',
        ...
      }: {
        inherit (rootFlake') formatter;
        treefmt.programs.alejandra.enable = true;

        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            (_: _: {
              inherit
                (inputs'.nixpkgs-21_11.legacyPackages)
                terraform_0_12
                terraform_0_13
                terraform_0_14
                terraform_0_15
                ;
            })
          ];
          config.allowUnfree = true;
        };

        imports = [./tests.nix];

        devshells.default = {
          commands = [
            {
              name = "repl";
              command = ''
                exec nix repl --file "$PRJ_ROOT/dev/repl.nix" "$@"
              '';
              help = "Development REPL";
            }
            {package = pkgs.vulnix;}
          ];
        };
      };
    };
}
