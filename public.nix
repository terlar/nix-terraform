{config, ...}: {
  flake.lib.mkNixTerraformPkgsLib = import ./pkgs-lib;

  flake.overlays.default = final: _prev: let
    pkgsLib = config.flake.lib.mkNixTerraformPkgsLib {pkgs = final;};
  in {
    inherit
      (pkgsLib)
      writeTerraformVersions
      ;
  };

  perSystem = {pkgs, ...}: let
    pkgsExt = pkgs.extend config.flake.overlays.default;
  in {
    legacyPackages = {
      inherit
        (pkgsExt)
        writeTerraformVersions
        ;
    };
  };
}
