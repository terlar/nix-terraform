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
        rootFlake',
        ...
      }: {
        inherit (rootFlake') formatter;
        treefmt.programs.alejandra.enable = true;

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
