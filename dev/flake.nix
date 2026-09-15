{
  description = "Dependencies for development purposes";

  inputs = {
    dev-flake.url = "github:terlar/dev-flake";

    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    # For Terraform packages pre 1.x
    nixpkgs-21_11.url = "https://channels.nixos.org/nixos-21.11/nixexprs.tar.xz";
  };

  outputs = _: { };
}
