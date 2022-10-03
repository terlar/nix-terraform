{system ? builtins.currentSystem}: let
  flake = builtins.getFlake (toString ./.);
  testsFlake = builtins.getFlake (toString ./tests);
in {
  inherit flake system;
  inherit (flake.inputs.nixpkgs) lib;
  pkgs = import flake.inputs.nixpkgs {
    inherit system;
    overlays = builtins.attrValues flake.overlays;
  };
  checks = testsFlake.checks.${system};
}
