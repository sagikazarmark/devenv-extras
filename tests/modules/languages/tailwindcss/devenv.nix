{ config, pkgs, ... }:

{
  languages.tailwindcss.enable = true;

  assertions = [
    {
      assertion = config.languages.tailwindcss.package == pkgs.tailwindcss_4;
      message = "languages.tailwindcss.package should default to pkgs.tailwindcss_4.";
    }
    {
      assertion = builtins.elem pkgs.tailwindcss_4 config.packages;
      message = "languages.tailwindcss.enable should add pkgs.tailwindcss_4 to packages.";
    }
    {
      assertion = builtins.elem pkgs.tailwindcss-language-server config.packages;
      message = "languages.tailwindcss.lsp.enable should add pkgs.tailwindcss-language-server to packages.";
    }
  ];
}
