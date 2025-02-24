{
  description = "Aranet Prometheus Exporter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
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
    (flake-utils.lib.eachDefaultSystem (
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
        pname = "aranet-exporter";
        program = "${self.packages.${system}.default}/bin/${pname}";
      in
      {
        devShells.default = pkgs.mkShell {
          inherit buildInputs nativeBuildInputs;
        };
        packages.default = pkgs.rustPlatform.buildRustPackage {
          inherit pname;
          version = "0.1.0";
          cargoHash = "sha256-OewEmCmT93V5UrzNPA1C5T/hSrcybOfv6sjH9UccafU=";
          useFetchCargoVendor = true;
          src = ./.;
          inherit buildInputs nativeBuildInputs;
        };
        apps.default = {
          type = "app";
          inherit program;
        };
      }
    ))
    // {
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          pname = "aranet-exporter";
          description = "Aranet Prometheus Exporter";
        in
        {
          options.services.${pname} = {
            enable = lib.mkEnableOption description;

            addr = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Aranet sensor address";
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 9186;
              description = "Port to listen on";
            };
          };

          config = lib.mkIf config.services.${pname}.enable {
            systemd.services.${pname} = {
              inherit description;
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                # ExecStart = "${pkgs.${pname}}/bin/${pname}";
                ExecStart = "${self.packages.${pkgs.system}.default}/bin/${pname}";
                Restart = "always";
                Type = "simple";
                DynamicUser = "yes";
              };
              environment = {
                ARANET_ADDR = toString config.services.${pname}.addr;
                PORT = toString config.services.${pname}.port;
              };
            };
          };
        };
    };
}
