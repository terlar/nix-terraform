{
  lib,
  pkgs,
  inputs',
  rootFlake',
  ...
}: let
  nameForTest = {
    version,
    providers ? [],
    ...
  }: "writeTerraformVersions-with-${builtins.concatStringsSep "+" ([version] ++ providers)}";

  checkWriteTerraformVersions = pkgs.callPackage ./check-write-terraform-versions.nix {
    inherit (rootFlake'.legacyPackages) writeTerraformVersions;
    terraformPkgs = {
      inherit
        (inputs'.nixpkgs-21_11.legacyPackages)
        terraform_0_12
        terraform_0_13
        terraform_0_14
        terraform_0_15
        ;
      inherit
        (pkgs)
        terraform_1
        ;
    };
  };
in {
  checks =
    lib.pipe [
      {version = "0_12";}
      {version = "0_13";}
      {version = "0_14";}
      {version = "0_15";}
      {version = "1";}
      {
        version = "0_12";
        providers = ["aws"];
        useLockFile = false;
      }
      {
        version = "0_13";
        providers = ["aws"];
        useLockFile = false;
      }
      {
        version = "0_14";
        providers = ["aws"];
      }
      {
        version = "0_15";
        providers = ["aws"];
      }
      {
        version = "1";
        providers = ["aws"];
      }
    ] [
      (map (args: {
        name = nameForTest args;
        value = checkWriteTerraformVersions args;
      }))
      lib.listToAttrs
    ];
}
