{
  lib,
  pkgs,
  inputs',
  rootFlake',
  ...
}: {
  checks = let
    checkWriteTerraformVersions = pkgs.callPackage ./check-write-terraform-versions.nix {
      inherit (rootFlake'.legacyPackages) writeTerraformVersions;
    };
  in
    lib.listToAttrs (map
      (args @ {
        terraform,
        providers ? [],
        ...
      }: let
        version = lib.getVersion terraform;
        slug = builtins.concatStringsSep "-" (providers ++ [version]);
      in {
        name = "writeTerraformVersions-with-${slug}";
        value = checkWriteTerraformVersions args;
      })
      [
        {terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_12;}
        {terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_13;}
        {terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_14;}
        {terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_15;}
        {terraform = pkgs.terraform_1;}
        {
          terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_12;
          providers = ["aws"];
          useLockFile = false;
        }
        {
          terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_13;
          providers = ["aws"];
          useLockFile = false;
        }
        {
          terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_14;
          providers = ["aws"];
        }
        {
          terraform = inputs'.nixpkgs-21_11.legacyPackages.terraform_0_15;
          providers = ["aws"];
        }
        {
          terraform = pkgs.terraform_1;
          providers = ["aws"];
        }
      ]);
}
