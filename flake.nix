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

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) terraform_1_0 terraform-provider-aws;
      });
    };
}
