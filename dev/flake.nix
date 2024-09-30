{
  description = "Dependencies for development purposes";

  inputs = {
    dev-flake.url = "github:terlar/dev-flake";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # For Terraform packages pre 1.x
    nixpkgs-21_11.url = "github:nixos/nixpkgs/release-21.11";
  };

  outputs = _: { };
}
