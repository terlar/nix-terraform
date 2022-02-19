{
  description = "Nix Terraform tests";

  inputs.nixpkgs-release-21_11.url = "github:nixos/nixpkgs/release-21.11";
  inputs.nixpkgs-unstable.follows = "nix-terraform/nixpkgs";

  inputs.nix-terraform.url = "..";

  outputs = inputs:
    let
      inherit (inputs.nixpkgs-unstable) lib;
      forAllSystems = lib.genAttrs (builtins.attrNames inputs.nix-terraform.packages);
      forAllChannels = lib.genAttrs [ "release-21_11" "unstable" ];
      nixpkgsFor = forAllChannels
        (channel: forAllSystems
          (system: import inputs.${"nixpkgs-${channel}"}
            {
              inherit system;
              overlays = [ inputs.nix-terraform.overlay ];
            }));
    in
    {
      checks = forAllSystems
        (system:
          let
            checkWriteTerraformVersions = { channel ? "unstable", version, providers ? [ ], useLockFile ? (providers != [ ]) }:
              let
                pkgs = nixpkgsFor.${channel}.${system};
                terraform = pkgs."terraform_${version}";
                drv = inputs.nix-terraform.lib.writeTerraformVersions { inherit system terraform providers; };
              in
              pkgs.runCommand "check-terraform-${version}-versions"
                { nativeBuildInputs = [ pkgs.jq (terraform.withPlugins (ps: map (p: ps.${p}) providers)) ]; }
                ''
                  cd ${drv}
                  [ -f versions.tf.json ] || false
                  ${lib.optionalString useLockFile "[ -f .terraform.lock.hcl ] || false"}
                  ${lib.concatMapStringsSep "\n" (provider: ''
                    [ "$(jq -r .terraform.required_providers.${provider}.version < versions.tf.json)" = "${lib.getVersion pkgs.terraform-providers.${provider}}" ] || false
                  '') providers}

                  [ "$(jq -r .terraform.required_version < versions.tf.json)" = "${lib.getVersion terraform}" ] || false
                  export TF_DATA_DIR="$(mktemp -d)/.terraform"
                  terraform init -backend=false
                  touch $out
                '';
          in
          {
            inherit (inputs.nix-terraform.packages.${system}) terraform_1 terraform-provider-aws;
          } // lib.listToAttrs (map
            (args@{ version, providers ? [ ], ... }: {
              name = "writeTerraformVersions-with-${builtins.concatStringsSep "-" (providers ++ [ version ])}";
              value = checkWriteTerraformVersions args;
            })
            [
              { version = "0_12"; channel = "release-21_11"; }
              { version = "0_13"; }
              { version = "0_14"; }
              { version = "0_15"; }
              { version = "1"; }
              { version = "0_12"; providers = [ "aws" ]; useLockFile = false; channel = "release-21_11"; }
              { version = "0_13"; providers = [ "aws" ]; useLockFile = false; }
              { version = "0_14"; providers = [ "aws" ]; }
              { version = "0_15"; providers = [ "aws" ]; }
              { version = "1"; providers = [ "aws" ]; }
            ])
        );
    };
}
