{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    terranix,
  }: let
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
        overlays = [self.overlay];
      });
  in {
    lib = {
      mkNixTerraformPkgsLib = import ./pkgs-lib;
    };

    overlay = final: prev: let
      pkgsLib = self.lib.mkNixTerraformPkgsLib {
        inherit lib;
        pkgs = final;
      };
      sources = lib.importJSON ./sources.json;
    in {
      inherit (pkgsLib) writeTerraformVersions;

      terraform-providers =
        prev.terraform-providers
        // {
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

    packages = forAllSystems (system: {
      terraform = nixpkgsFor.${system}.terraform_1;
      terraform-provider-aws = nixpkgsFor.${system}.terraform-providers.aws;
    });

    apps = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      terraform = {
        type = "app";
        program = "${self.packages.${system}.terraform.withPlugins (p: [p.aws])}/bin/terraform";
      };

      update-terraform = let
        drv = pkgs.writeShellApplication {
          name = "update-terraform";
          runtimeInputs = [pkgs.nix pkgs.curl pkgs.jq pkgs.moreutils];
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
      in {
        type = "app";
        program = "${drv}/bin/${drv.meta.mainProgram}";
      };

      update-provider-aws = let
        drv = pkgs.writeShellApplication {
          name = "update-provider-aws";
          runtimeInputs = [pkgs.nix pkgs.curl pkgs.jq pkgs.moreutils];
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
      in {
        type = "app";
        program = "${drv}/bin/${drv.meta.mainProgram}";
      };
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    devShell = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      pkgs.mkShell {
        propagatedBuildInputs = [
          pkgs.nixpkgs-fmt
          pkgs.statix
        ];
      });

    checks = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      format =
        pkgs.runCommand "check-format"
        {nativeBuildInputs = [pkgs.alejandra];}
        ''
          cd ${self}
          alejandra --check .
          mkdir $out
        '';

      lint =
        pkgs.runCommand "check-lint"
        {nativeBuildInputs = [pkgs.statix];}
        ''
          cd ${self}
          statix check .
          mkdir $out
        '';
    });
  };
}
