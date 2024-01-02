{
  lib,
  pkgs,
  rootFlake',
  ...
}: let
  nameForTest = name: {
    package,
    providers ? [],
    ...
  }: "${name}-with-${lib.pipe package [
    (builtins.getAttr "name")
    (builtins.replaceStrings ["."] ["_"])
    lib.singleton
    ((lib.flip lib.concat) providers)
    (builtins.concatStringsSep "+")
  ]}";

  checkWriteTerraformVersions = pkgs.callPackage ./check-write-terraform-versions.nix {
    inherit (rootFlake'.legacyPackages) writeTerraformVersions;
  };

  mkChecks = {
    sets,
    fn,
  }: {
    checks = lib.pipe sets [
      lib.cartesianProductOfSets
      (map fn)
      lib.listToAttrs
    ];
  };
in
  lib.mkMerge [
    (mkChecks {
      sets = {
        package = [
          pkgs.opentofu
          pkgs.terraform_0_12
          pkgs.terraform_0_13
          pkgs.terraform_0_14
          pkgs.terraform_0_15
          pkgs.terraform_1
        ];
        providers = [[] ["aws"]];
      };
      fn = args: {
        name = nameForTest "writeTerraformVersions" args;
        value = checkWriteTerraformVersions args;
      };
    })
  ]
