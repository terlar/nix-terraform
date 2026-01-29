{
  lib,
  jq,
  runCommand,
  writeTerraformVersions,
}:
{
  package,
  providers ? [ ],
}:
let
  providerNames = map (
    name: if package.plugins ? ${name} then name else lib.removePrefix "hashicorp_" name
  ) providers;

  packageWithProviders = package.withPlugins (ps: map (p: ps.${p}) providerNames);

  mainProgram = package.meta.mainProgram or "terraform";
  version = lib.pipe package [
    lib.getVersion
    (lib.splitString "-")
    builtins.head
  ];
  useLockFile = providers != [ ] && lib.versionAtLeast version "0.14.0";

  drv = writeTerraformVersions {
    inherit package;
    providers = providerNames;
  };

  providerNameFromProviderSource =
    name:
    lib.pipe name [
      (builtins.split "/")
      lib.lists.last
    ];

  providers' = map (
    name:
    let
      provider = package.plugins.${name};
    in
    {
      name = providerNameFromProviderSource provider.provider-source-address;
      version = lib.getVersion provider;
    }
  ) providerNames;
in
runCommand "check-${package.name}-versions"
  {
    nativeBuildInputs = [
      jq
      packageWithProviders
    ];
    passthru = {
      inherit drv;
    };
  }
  ''
    cd ${drv}
    [ -f versions.tf.json ] || false
    ${lib.optionalString useLockFile "[ -f .terraform.lock.hcl ] || false"}
    ${lib.concatMapStringsSep "\n" (
      { name, version }:
      ''
        [ "$(jq -r .terraform.required_providers.${name}.version < versions.tf.json)" = "${version}" ] || false
      ''
    ) providers'}

    [ "$(jq -r .terraform.required_version < versions.tf.json)" = "${version}" ] || false
    export TF_DATA_DIR="$(mktemp -d)/.terraform"
    ${mainProgram} init -backend=false
    touch $out
  ''
