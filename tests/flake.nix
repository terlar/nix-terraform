{
  description = "Nix Terraform tests";

  inputs.nixpkgs-release-21_11.url = "github:nixos/nixpkgs/release-21.11";
  inputs.nixpkgs-unstable.follows = "nix-terraform/nixpkgs";

  inputs.nix-terraform.url = "github:terlar/nix-terraform";

  outputs = inputs: let
    inherit (inputs.nixpkgs-unstable) lib;
    forAllSystems = lib.genAttrs (builtins.attrNames inputs.nix-terraform.packages);
    forAllChannels = lib.genAttrs ["release-21_11" "unstable"];
    nixpkgsFor =
      forAllChannels
      (channel:
        forAllSystems
        (system:
          import inputs.${"nixpkgs-${channel}"}
          {
            inherit system;
            overlays = builtins.attrValues inputs.nix-terraform.overlays;
          }));
  in {
    inherit (inputs.nix-terraform) formatter;

    checks =
      forAllSystems
      (
        system: let
          checkWriteTerraformVersions = {
            channel ? "unstable",
            version,
            providers ? [],
            useLockFile ? (providers != []),
          }: let
            pkgs = nixpkgsFor.${channel}.${system};
            terraform = pkgs."terraform_${version}";
            drv = pkgs.writeTerraformVersions {inherit terraform providers;};
          in
            pkgs.runCommand "check-terraform-${version}-versions" {
              nativeBuildInputs = [pkgs.jq (terraform.withPlugins (ps: map (p: ps.${p}) providers))];
              passthru = {inherit drv;};
            } ''
              cd ${drv}
              [ -f versions.tf.json ] || false
              ${lib.optionalString useLockFile "[ -f .terraform.lock.hcl ] || false"}
              ${lib.concatMapStringsSep "\n" (provider: ''
                  [ "$(jq -r .terraform.required_providers.${provider}.version < versions.tf.json)" = "${lib.getVersion pkgs.terraform-providers.${provider}}" ] || false
                '')
                providers}

              [ "$(jq -r .terraform.required_version < versions.tf.json)" = "${lib.getVersion terraform}" ] || false
              export TF_DATA_DIR="$(mktemp -d)/.terraform"
              terraform init -backend=false
              touch $out
            '';
        in
          lib.listToAttrs (map
            (args @ {
              version,
              providers ? [],
              ...
            }: {
              name = "writeTerraformVersions-with-${builtins.concatStringsSep "-" (providers ++ [version])}";
              value = checkWriteTerraformVersions args;
            })
            [
              {
                version = "0_12";
                channel = "release-21_11";
              }
              {
                version = "0_13";
                channel = "release-21_11";
              }
              {
                version = "0_14";
                channel = "release-21_11";
              }
              {
                version = "0_15";
                channel = "release-21_11";
              }
              {version = "1";}
              {
                version = "0_12";
                providers = ["aws"];
                useLockFile = false;
                channel = "release-21_11";
              }
              {
                version = "0_13";
                providers = ["aws"];
                useLockFile = false;
                channel = "release-21_11";
              }
              {
                version = "0_14";
                providers = ["aws"];
                channel = "release-21_11";
              }
              {
                version = "0_15";
                providers = ["aws"];
                channel = "release-21_11";
              }
              {
                version = "1";
                providers = ["aws"];
              }
            ])
      );
  };
}
