{
  lib,
  jq,
  runCommand,
  writeTerraformVersions,
}: {
  package,
  providers ? [],
  useLockFile ? (providers != []),
}: let
  packageWithProviders = package.withPlugins (ps: map (p: ps.${p}) providers);

  mainProgram = package.meta.mainProgram or "terraform";
  version = lib.pipe package [
    lib.getVersion
    (lib.splitString "-")
    builtins.head
  ];

  drv = writeTerraformVersions {inherit package providers;};
in
  runCommand "check-${package.name}-versions" {
    nativeBuildInputs = [jq packageWithProviders];
    passthru = {inherit drv;};
  } ''
    cd ${drv}
    [ -f versions.tf.json ] || false
    ${lib.optionalString useLockFile "[ -f .terraform.lock.hcl ] || false"}
    ${lib.concatMapStringsSep "\n" (provider: ''
        [ "$(jq -r .terraform.required_providers.${provider}.version < versions.tf.json)" = "${lib.getVersion package.plugins.${provider}}" ] || false
      '')
      providers}

    [ "$(jq -r .terraform.required_version < versions.tf.json)" = "${version}" ] || false
    export TF_DATA_DIR="$(mktemp -d)/.terraform"
    ${mainProgram} init -backend=false
    touch $out
  ''
