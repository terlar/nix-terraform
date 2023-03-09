{pkgs}: {
  writeTerraformVersions = pkgs.callPackage ./write-terraform-versions.nix {};
}
