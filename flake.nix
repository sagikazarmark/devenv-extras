{
  description = "Extra devenv modules and packages";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = lib.genAttrs supportedSystems;
      packagesFor = pkgs: import ./packages { inherit pkgs; };

      # Build helpers, which are not packages.
      buildersFor = pkgs: {
        buildPhpRustExtension = pkgs.callPackage ./modules/integrations/php-ext-rs/build.nix { };
      };
    in
    {
      overlays.dang = final: _prev: {
        inherit (packagesFor final) dang;
      };

      overlays.sandbox-agent = final: _prev: {
        inherit (packagesFor final) sandbox-agent;
      };

      overlays.php-ext-rs = final: _prev: buildersFor final;

      overlays.default = final: _prev: packagesFor final // buildersFor final;

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        packagesFor pkgs
      );

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.php-ext-rs ];
          };

          fixture = ./tests/modules/integrations/php-ext-rs-import;

          phpExtension = pkgs.buildPhpRustExtension {
            php = pkgs.php84;
            extensionName = "hello";
            version = "0.1.0";
            src = lib.fileset.toSource {
              root = fixture;
              fileset = lib.fileset.unions [
                (fixture + "/Cargo.toml")
                (fixture + "/Cargo.lock")
                (fixture + "/src")
              ];
            };
            cargoLock.lockFile = fixture + "/Cargo.lock";
          };
        in
        {
          inherit (self.packages.${system}) dang sandbox-agent;
        }
        # nixpkgs may not have PHP for every system.
        // lib.optionalAttrs (builtins.tryEval pkgs.php84.drvPath).success {
          php-ext-rs = phpExtension.tests.load;
        }
      );
    };
}
