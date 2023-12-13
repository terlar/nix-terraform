{
  pkgs,
  lib ? pkgs.lib,
}: {
  # Create a versions.tf.json file for given terraform and list of provider names.
  # You either have to name a system or set pkgs.
  writeTerraformVersions = {
    package,
    providers ? [],
  }: let
    filename = "versions.tf.json";

    packageWithProviders = package.withPlugins (p: map (name: p.${name}) providers);

    mainProgram = package.meta.mainProgram or "terraform";
    version = lib.pipe package [
      lib.getVersion
      (lib.splitString "-")
      builtins.head
    ];

    useDependencyLockfile =
      providers != [] && lib.versionAtLeast version "0.14.0";

    config = {
      terraform = {
        required_version = version;
        required_providers = lib.genAttrs providers (name: let
          provider = package.plugins.${name};
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
        [pkgs.jq] ++ lib.optional useDependencyLockfile packageWithProviders;
      buildPhase = ''
        jq . "$valuePath" > ${filename}
        ${lib.optionalString useDependencyLockfile ''
          ${mainProgram} init -backend=false
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
