{
  pkgs,
  terranixConfiguration,
}: rec {
  mkTerraformDerivation = pkgs.callPackage ./mk-terraform-derivation.nix {
    inherit terranixConfiguration writeTerraformVersions;
  };

  writeTerraformVersions = pkgs.callPackage ./write-terraform-versions.nix {};
}
