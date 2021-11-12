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
          { system ? ""
          , pkgs ? nixpkgsFor.${system}
          , terraform
          , providers ? [ ]
          }:
          let
            filename = "versions.tf.json";

            useDependencyLockfile =
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
        inherit (nixpkgsFor.${system}) terraform_1_0;
        terraform-provider-aws = nixpkgsFor.${system}.terraform-providers.aws;
      });

      apps = forAllSystems (system: {
        terraform = {
          type = "app";
          program =
            "${self.packages.${system}.terraform_1_0.withPlugins (p: [ p.aws ])}/bin/terraform";
        };
      });

      overlay = final: prev: {
        terraform-providers = prev.terraform-providers // {
          aws = prev.terraform-providers.mkProvider rec {
            inherit (prev.terraform-providers.aws) owner repo provider-source-address;
            version = "3.64.2";
            rev = "v${version}";
            sha256 = "sha256-y+AhnaZArG0NJvqK+NGg3+In3ywO2UV4ofhhWkX5gZg=";
            vendorSha256 = "sha256-YotTYItzr7os3kLV6GZYZVzTfJ1LnsHD4UJ+7P6DPGU=";
          };
        };

        terraform_1_0 = prev.mkTerraform {
          version = "1.0.11";
          sha256 = "sha256-Z2qFetJZgylRbf75oKEr8blPhQcABxcE1nObUD/RBUw=";
          vendorSha256 = "sha256-4oSL7QT6KjZlt3NKkjNWcrZA8yCkx6aI2kYsdyh8L68=";
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
        (system: {
          inherit (self.packages.${system}) terraform_1_0 terraform-provider-aws;
          build-writeTerraformVersions = self.lib.writeTerraformVersions {
            inherit system;
            terraform = self.packages.${system}.terraform_1_0;
            providers = [ "aws" ];
          };
        });
    };
}
