{inputs, ...}: {
  imports = [
    inputs.devshell.flakeModule
    inputs.pre-commit-hooks.flakeModule
    inputs.treefmt.flakeModule
  ];

  perSystem = {
    config,
    pkgs,
    ...
  }: {
    formatter = pkgs.alejandra;
    treefmt.programs.alejandra.enable = true;

    treefmt = {
      flakeFormatter = false;
      projectRootFile = "flake.nix";
    };

    pre-commit = {
      check.enable = true;
      settings.hooks = {
        deadnix.enable = true;
        statix.enable = true;
        treefmt.enable = true;
      };
    };

    devshells.default = {
      name = "terlar/nix-terraform";
      devshell.startup.pre-commit-install.text = config.pre-commit.installationScript;

      commands = [
        {
          name = "repl";
          command = ''
            exec nix repl --file repl.nix "$@"
          '';
          help = "Development REPL";
        }
        {package = pkgs.vulnix;}
      ];
    };
  };
}
