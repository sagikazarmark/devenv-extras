{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.languages.dang;
in
{
  options.languages.dang = {
    enable = lib.mkEnableOption "tools for Dang development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dang or (pkgs.callPackage ./package.nix { });
      defaultText = lib.literalExpression "pkgs.dang or (pkgs.callPackage ./package.nix { })";
      description = "The Dang package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      cfg.package
    ];
  };
}
