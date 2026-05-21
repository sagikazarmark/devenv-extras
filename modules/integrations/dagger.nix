{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.dagger;

  input = config.lib.getInput {
    name = "dagger";
    url = "github:dagger/nix";
    attribute = "dagger.enable";
    follows = [ "nixpkgs" ];
  };
in
{
  options.dagger = {
    enable = lib.mkEnableOption "Dagger";

    package = lib.mkOption {
      type = lib.types.package;
      default = input.packages.${pkgs.stdenv.hostPlatform.system}.dagger;
      defaultText = lib.literalExpression "dagger.packages.\${pkgs.stdenv.hostPlatform.system}.dagger";
      description = "The Dagger package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    languages.dang.enable = true;

    packages = [
      cfg.package
    ];
  };
}
