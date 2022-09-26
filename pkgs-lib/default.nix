{
  pkgs,
  lib ? pkgs.lib,
}: {
  # Create a versions.tf.json file for given terraform and list of provider names.
  # You either have to name a system or set pkgs.
  writeTerraformVersions = {
    terraform,
    providers ? [],
  }: let
    filename = "versions.tf.json";

    terraformWithProviders = terraform.withPlugins (p: map (name: p.${name}) providers);

    useDependencyLockfile =
      providers != [] && lib.versionAtLeast (lib.getVersion terraform) "0.14.0";

    config = {
      terraform = {
        required_version = lib.getVersion terraform;
        required_providers = lib.genAttrs providers (name: let
          provider = pkgs.terraform-providers.${name};
        in {
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
      passAsFile = ["value"];

      nativeBuildInputs =
        [pkgs.jq] ++ lib.optional useDependencyLockfile terraformWithProviders;
      buildPhase = ''
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

      passthru = {inherit config;};
    };
}
