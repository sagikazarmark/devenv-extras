{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.languages.tailwindcss;
in
{
  options.languages.tailwindcss = {
    enable = lib.mkEnableOption "tools for Tailwind CSS development";

    package = lib.mkPackageOption pkgs "Tailwind CSS" { default = "tailwindcss_4"; };

    lsp = {
      enable = lib.mkEnableOption "Tailwind CSS language server" // {
        default = true;
      };

      package = lib.mkPackageOption pkgs "Tailwind CSS language server" {
        default = "tailwindcss-language-server";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      cfg.package
    ]
    ++ lib.optional cfg.lsp.enable cfg.lsp.package;
  };
}
