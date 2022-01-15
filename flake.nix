{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, terranix }:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [
        "aarch64-linux"
        "aarch64-darwin"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = f: lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        });
    in
    {
      lib = {
        # Create a versions.tf.json file for given terraform and list of provider names.
        # You either have to name a system or set pkgs.
        writeTerraformVersions =
          { terraform
          , providers ? [ ]
          , system ? ""
          , pkgs ? nixpkgsFor.${system}
          }:
          let
            filename = "versions.tf.json";

            useDependencyLockfile = providers != [ ] &&
              lib.versionAtLeast (lib.getVersion terraform) "0.14.0";

            config = {
              terraform = {
                required_version = lib.getVersion terraform;
                required_providers = lib.genAttrs providers (name:
                  let provider = pkgs.terraform-providers.${name};
                  in
                  {
                    version = lib.getVersion provider;
                    source = provider.provider-source-address;
                  });
              };
            };
          in
          pkgs.stdenv.mkDerivation {
            name = "versions-tf";

            dontUnpack = true;
            value = builtins.toJSON config;
            passAsFile = [ "value" ];

            nativeBuildInputs = [ pkgs.jq ] ++ lib.optional useDependencyLockfile
              (terraform.withPlugins (p: map (name: p.${name}) providers));
            buildPhase = ''
              ls -la
              jq . "$valuePath" > ${filename}
              ${lib.optionalString useDependencyLockfile ''
                terraform init -backend=false
              ''}
            '';

            installPhase = ''
              mkdir -p $out
              cp ${filename} $out
              ${lib.optionalString useDependencyLockfile ''
                cp .terraform.lock.hcl $out
              ''}
            '';

            passthru = { inherit config; };
          };
      };

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) terraform_1;
        terraform-provider-aws = nixpkgsFor.${system}.terraform-providers.aws;
      });

      apps = forAllSystems (system: {
        terraform = {
          type = "app";
          program =
            "${self.packages.${system}.terraform_1.withPlugins (p: [ p.aws ])}/bin/terraform";
        };
      });

      overlay = final: prev: {
        terraform-providers = prev.terraform-providers // {
          aws = prev.terraform-providers.mkProvider rec {
            inherit (prev.terraform-providers.aws) owner repo provider-source-address;
            version = "3.70.0";
            rev = "v${version}";
            sha256 = "sha256-ohN5CfXVMfAbPA6fyTdLW2US5KzcsfgTR/0o/mxwYwQ=";
            vendorSha256 = "sha256-hHdEfd++fSsC0RRb7UN0zn/xxUx8Kx7Yb4sr92XsaA4=";
          };
        };

        terraform_1 = prev.mkTerraform {
          version = "1.1.2";
          sha256 = "sha256-8M/hs4AiApe9C19VnVhWYYOkKqXbv3aREUTNfExTDww=";
          vendorSha256 = "sha256-inPNvNUcil9X0VQ/pVgZdnnmn9UCfEz7qXiuKDj8RYM=";
          patches = [
            "${nixpkgs}/pkgs/applications/networking/cluster/terraform/provider-path-0_15.patch"
          ];
          passthru = {
            plugins = removeAttrs final.terraform-providers [
              "override"
              "overrideDerivation"
              "recurseForDerivations"
            ];
          };
        };
      };

      checks = forAllSystems
        (system:
          let
            pkgs = nixpkgsFor.${system};
            checkWriteTerraformVersions = { version, providers ? [ ], useLockFile ? (providers != [ ]) }:
              let
                terraform = pkgs."terraform_${version}";
                drv = self.lib.writeTerraformVersions { inherit system terraform providers; };
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
            inherit (self.packages.${system}) terraform_1 terraform-provider-aws;
          } // lib.listToAttrs (map
            (args@{ version, providers ? [ ], ... }: {
              name = "writeTerraformVersions-with-${builtins.concatStringsSep "-" (providers ++ [ version ])}";
              value = checkWriteTerraformVersions args;
            })
            [
              { version = "0_12"; }
              { version = "0_13"; }
              { version = "0_14"; }
              { version = "0_15"; }
              { version = "1"; }
              { version = "0_12"; providers = [ "aws" ]; useLockFile = false; }
              { version = "0_13"; providers = [ "aws" ]; useLockFile = false; }
              { version = "0_14"; providers = [ "aws" ]; }
              { version = "0_15"; providers = [ "aws" ]; }
              { version = "1"; providers = [ "aws" ]; }
            ])
        );
    };
}
