{system ? builtins.currentSystem}: let
  flake = builtins.getFlake (toString ./..);
  devFlake = builtins.getFlake (toString ./.);
in {
  inherit flake devFlake system;
  inherit (devFlake.inputs.nixpkgs) lib;
  pkgs = import flake.inputs.nixpkgs {
    inherit system;
    overlays = builtins.attrValues flake.overlays;
  };
  tests = devFlake.checks.${system};
}
