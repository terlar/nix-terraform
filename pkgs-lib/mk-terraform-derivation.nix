{
  lib,
  coreutils,
  linkFarmFromDrvs,
  makeWrapper,
  symlinkJoin,
  terranixConfiguration,
  writeTerraformVersions,
}:
# Create a derivation of a terraform root module directory for a opentofu/terraform
# package and list of provider names.
#
# Extra paths can be included via paths.
{
  name,
  package,
  # Providers to use.
  providers ? [ ],
  # Terranix modules.
  terranixModules ? [ ],
  # Paths to be included in the derivation (must be directories).
  paths ? [ ],
  # Perform validation of Terraform.
  validate ? true,
}:
let
  mainProgram = package.meta.mainProgram or "terraform";
  packageWithProviders = package.withPlugins (p: map (name: p.${name}) providers);

  configFromTerranixModules = terranixConfiguration {
    modules = terranixModules;
  };
in
symlinkJoin {
  name = "${name}-tf";
  paths =
    [
      # Add versions file
      (writeTerraformVersions { inherit providers package; })
    ]
    ++ paths
    ++ (lib.optional (terranixModules != [ ]) (
      linkFarmFromDrvs "${name}-tf-config" [ configFromTerranixModules ]
    ));

  postBuild =
    let
      makeWrapperArgs = lib.strings.escapeShellArgs (
        [
          "--run"
          ''
            if [ -n "''${TRACE:-}" ]; then
              set -o xtrace
              export TF_LOG=1
            fi
          ''
          "--run"
          ''dir="$(${coreutils}/bin/readlink -f "''${0%/*}/..")" ''
          "--run"
          ''export TF_DATA_DIR="''${TF_DATA_DIR:-''${TMPDIR:-/tmp}/.terraform-''${dir##*/}}"''
        ]
        ++ (
          if lib.versionAtLeast (lib.getVersion package) "0.15.0" then
            [
              "--prefix"
              "TF_CLI_ARGS_init"
              " "
              "-lockfile=readonly"
              "--add-flags"
              ''-chdir="$dir"''
            ]
          else
            [
              "--run"
              ''cd "$dir"''
            ]
        )
      );
    in
    ''
      makeWrapper ${packageWithProviders}/bin/${mainProgram} $out/bin/${mainProgram} ${makeWrapperArgs}

      ${lib.optionalString validate ''
        $out/bin/${mainProgram} init -backend=false
        $out/bin/${mainProgram} validate
      ''}
    '';

  nativeBuildInputs = [ makeWrapper ];
}
