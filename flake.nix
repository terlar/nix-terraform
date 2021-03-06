{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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

      forAllSystems = lib.genAttrs supportedSystems;
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
        terraform = nixpkgsFor.${system}.terraform_1;
        terraform-provider-aws = nixpkgsFor.${system}.terraform-providers.aws;
      });

      apps = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          terraform = {
            type = "app";
            program =
              "${self.packages.${system}.terraform.withPlugins (p: [ p.aws ])}/bin/terraform";
          };

          update-terraform =
            let
              drv = pkgs.writeShellApplication {
                name = "update-terraform";
                runtimeInputs = [ pkgs.nix pkgs.curl pkgs.jq pkgs.moreutils ];
                text = ''
                  version="$(curl https://api.github.com/repos/hashicorp/terraform/releases/latest | jq --raw-output '.tag_name' | cut -c 2-)"
                  sha256="$(nix-prefetch-url --unpack "https://github.com/hashicorp/terraform/archive/v$version.tar.gz")"

                  jq --arg version "$version" --arg sha256 "$sha256" \
                    '.terraform.version = $version | .terraform.sha256 = $sha256' \
                    < sources.json | sponge sources.json

                  vendorSha256="$(nix build .#packages.x86_64-linux.terraform 2>&1 | grep --extended-regexp --only-matching "sha256-[A-Za-z0-9/+=]+" | tail -n1; true)"

                  jq --arg vendorSha256 "$vendorSha256" \
                    '.terraform.vendorSha256 = $vendorSha256' \
                    < sources.json | sponge sources.json
                '';
              };
            in
            {
              type = "app";
              program = "${drv}/bin/${drv.meta.mainProgram}";
            };

          update-provider-aws =
            let
              drv = pkgs.writeShellApplication {
                name = "update-provider-aws";
                runtimeInputs = [ pkgs.nix pkgs.curl pkgs.jq pkgs.moreutils ];
                text = ''
                  version="$(curl -s https://registry.terraform.io/v1/providers/hashicorp/aws | jq -r .version)"
                  sha256="$(nix-prefetch-url --unpack "https://github.com/hashicorp/terraform-provider-aws/archive/v$version.tar.gz")"

                  jq --arg version "$version" --arg rev "v$version" --arg sha256 "$sha256" \
                    '.aws.version = $version | .aws.rev = $rev | .aws.sha256 = $sha256' \
                    < sources.json | sponge sources.json

                  vendorSha256="$(nix build .#packages.x86_64-linux.terraform-provider-aws 2>&1 | grep --extended-regexp --only-matching "sha256-[A-Za-z0-9/+=]+" | tail -n1; true)"

                  jq --arg vendorSha256 "$vendorSha256" \
                    '.aws.vendorSha256 = $vendorSha256' \
                    < sources.json | sponge sources.json
                '';
              };
            in
            {
              type = "app";
              program = "${drv}/bin/${drv.meta.mainProgram}";
            };
        });

      overlay = final: prev:
        let sources = lib.importJSON ./sources.json; in
        {
          terraform-providers = prev.terraform-providers // {
            aws = prev.terraform-providers.mkProvider sources.aws;
          };

          terraform_1 = prev.mkTerraform {
            inherit (sources.terraform) version sha256 vendorSha256;
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

      devShell = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        pkgs.mkShell {
          propagatedBuildInputs = [
            pkgs.nixpkgs-fmt
            pkgs.statix
          ];
        });

      checks = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          format = pkgs.runCommand "check-format"
            { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; }
            ''
              cd ${self}
              nixpkgs-fmt --check .
              mkdir $out
            '';

          lint = pkgs.runCommand "check-lint"
            { nativeBuildInputs = [ pkgs.statix ]; }
            ''
              cd ${self}
              statix check .
              mkdir $out
            '';
        });
    };
}
