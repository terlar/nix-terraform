{
  lib,
  pkgs,
  rootFlake',
  ...
}: let
  nameForTest = {
    package,
    providers ? [],
    ...
  }: "writeTerraformVersions-with-${lib.pipe package [
    (builtins.getAttr "name")
    (builtins.replaceStrings ["."] ["_"])
    lib.singleton
    ((lib.flip lib.concat) providers)
    (builtins.concatStringsSep "+")
  ]}";

  checkWriteTerraformVersions = pkgs.callPackage ./check-write-terraform-versions.nix {
    inherit (rootFlake'.legacyPackages) writeTerraformVersions;
  };
in {
  checks =
    lib.pipe [
      {package = pkgs.terraform_0_12;}
      {package = pkgs.terraform_0_13;}
      {package = pkgs.terraform_0_14;}
      {package = pkgs.terraform_0_15;}
      {package = pkgs.terraform_1;}
      {package = pkgs.opentofu;}
      {
        package = pkgs.terraform_0_12;
        providers = ["aws"];
        useLockFile = false;
      }
      {
        package = pkgs.terraform_0_13;
        providers = ["aws"];
        useLockFile = false;
      }
      {
        package = pkgs.terraform_0_14;
        providers = ["aws"];
      }
      {
        package = pkgs.terraform_0_15;
        providers = ["aws"];
      }
      {
        package = pkgs.terraform_1;
        providers = ["aws"];
      }
      {
        package = pkgs.opentofu;
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
