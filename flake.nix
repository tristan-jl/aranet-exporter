{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        buildInputs = with pkgs; [
          rustToolchain
          dbus
        ];
        nativeBuildInputs = with pkgs; [
          pkg-config
        ];
      in
      with pkgs;
      {
        devShells.default = mkShell {
          inherit buildInputs nativeBuildInputs;
        };
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "aranet-exporter";
          version = "0.1.0";
          cargoHash = "sha256-OewEmCmT93V5UrzNPA1C5T/hSrcybOfv6sjH9UccafU=";
          useFetchCargoVendor = true;
          src = ./.;
          inherit buildInputs nativeBuildInputs;
        };
      }
    );
}
