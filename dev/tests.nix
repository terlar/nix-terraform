{
  lib,
  config,
  pkgs,
  ...
}:
let
  nameForTest =
    name:
    {
      package,
      providers ? [ ],
      ...
    }:
    "${name}-with-${
      lib.pipe package [
        (builtins.getAttr "name")
        (builtins.replaceStrings [ "." ] [ "_" ])
        lib.singleton
        ((lib.flip lib.concat) providers)
        (builtins.concatStringsSep "+")
      ]
    }";

  checkWriteTerraformVersions = pkgs.callPackage ./packages/check-write-terraform-versions {
    inherit (config.legacyPackages) writeTerraformVersions;
  };

  mkChecks =
    {
      sets,
      fn,
    }:
    {
      checks = lib.pipe sets [
        lib.cartesianProduct
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
      providers = [
        [ ]
        [ "hashicorp_random" ]
      ];
    };
    fn = args: {
      name = nameForTest "writeTerraformVersions" args;
      value = checkWriteTerraformVersions args;
    };
  })

  (mkChecks {
    sets = {
      package = [
        pkgs.opentofu
        pkgs.terraform_1
      ];
      args = [
        {
          providers = [ ];
          paths = [
            (pkgs.writeTextDir "backend.tf" ''
              terraform {
                backend "local" {}
              }
            '')
          ];
        }
        {
          providers = [ "hashicorp_random" ];
          terranixModules = [
            {
              terraform.backend.local = { };
              resource.random_uuid.test = { };
            }
          ];
        }
      ];
    };
    fn =
      {
        package,
        args,
      }:
      let
        name = nameForTest "mkTerraformDerivation" (args // { inherit package; });
        mainProgram = package.meta.mainProgram or "terraform";
        drv = config.legacyPackages.mkTerraformDerivation (args // { inherit name package; });
      in
      {
        inherit name;
        value =
          pkgs.runCommand "check-${name}"
            {
              nativeBuildInputs = [ drv ];
              passthru = {
                inherit drv;
              };
            }
            ''
              export TF_INPUT=0
              export TF_IN_AUTOMATION=1
              ${mainProgram} init -backend-config=path=$out/terraform.tfstate
              ${mainProgram} apply -auto-approve
              ${mainProgram} state list
            '';
      };
  })
]
