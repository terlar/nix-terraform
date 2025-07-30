{ inputs, ... }:

{
  imports = [ inputs.dev-flake.flakeModule ];

  dev.name = "terlar/nix-terraform";

  perSystem =
    {
      pkgs,
      system,
      inputs',
      ...
    }:
    {
      pre-commit.settings.hooks = {
        conform.enable = true;
      };

      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (_: _: {
            inherit (inputs'.nixpkgs-21_11.legacyPackages)
              terraform_0_12
              terraform_0_13
              terraform_0_14
              terraform_0_15
              ;
          })
        ];
        config.allowUnfree = true;
      };

      imports = [ ./tests.nix ];

      devshells.default = {
        commands = [
          {
            name = "repl";
            command = ''
              exec nix repl --file "$PRJ_ROOT/dev/repl.nix" "$@"
            '';
            help = "Development REPL";
          }
          { package = pkgs.vulnix; }
        ];
      };
    };
}
