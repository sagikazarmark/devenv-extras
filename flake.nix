{
  description = "Extra devenv modules and packages";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      packagesFor = pkgs: import ./packages { inherit pkgs; };
    in
    {
      overlays.dang = final: _prev: {
        inherit (packagesFor final) dang;
      };

      overlays.sandbox-agent = final: _prev: {
        inherit (packagesFor final) sandbox-agent;
      };

      overlays.default = final: _prev: packagesFor final;

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        packagesFor pkgs
      );

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) dang sandbox-agent;
      });
    };
}
