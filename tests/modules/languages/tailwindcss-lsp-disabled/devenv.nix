{ config, pkgs, ... }:

{
  languages.tailwindcss = {
    enable = true;
    lsp.enable = false;
  };

  assertions = [
    {
      assertion = !(builtins.elem pkgs.tailwindcss-language-server config.packages);
      message = "languages.tailwindcss.lsp.enable = false should not add the language server to packages.";
    }
  ];
}
