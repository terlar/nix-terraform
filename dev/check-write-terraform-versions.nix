{
  lib,
  jq,
  runCommand,
  writeTerraformVersions,
}: {
  terraform,
  providers ? [],
  useLockFile ? (providers != []),
}: let
  version = lib.getVersion terraform;
  drv = writeTerraformVersions {inherit terraform providers;};
in
  runCommand "check-terraform-${version}-versions" {
    nativeBuildInputs = [jq (terraform.withPlugins (ps: map (p: ps.${p}) providers))];
    passthru = {inherit drv;};
  } ''
    cd ${drv}
    [ -f versions.tf.json ] || false
    ${lib.optionalString useLockFile "[ -f .terraform.lock.hcl ] || false"}
    ${lib.concatMapStringsSep "\n" (provider: ''
        [ "$(jq -r .terraform.required_providers.${provider}.version < versions.tf.json)" = "${lib.getVersion terraform.plugins.${provider}}" ] || false
      '')
      providers}

    [ "$(jq -r .terraform.required_version < versions.tf.json)" = "${lib.getVersion terraform}" ] || false
    export TF_DATA_DIR="$(mktemp -d)/.terraform"
    terraform init -backend=false
    touch $out
  ''
