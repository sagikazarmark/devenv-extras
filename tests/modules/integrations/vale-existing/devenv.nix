{ config, pkgs, ... }:

let
  vale = pkgs.writeShellScriptBin "vale" ''
    set -euo pipefail
    test "$#" -eq 5
    test "$1" = '--config'
    test "$2" = "$DEVENV_ROOT/.vale.ini"
    test "$3" = 'sync'
    test "$4" = '--output'
    test "$5" = 'argument with spaces'
    test "$VALE_CONFIG_PATH" = "$2"
    test "$VALE_STYLES_PATH" = "$DEVENV_ROOT/.devenv/custom styles"
    test -d "$VALE_STYLES_PATH"
    grep -q '^; Existing project configuration' "$2"
    touch synced
  '';
in
{
  vale = {
    enable = true;
    config.file = ".vale.ini";
    stylesPath = ".devenv/custom styles";
    sync.enable = true;
    package = vale;
    lsp.package = pkgs.hello;
    sync.arguments = [
      "--output"
      "argument with spaces"
    ];
  };

  assertions = [
    {
      assertion = config.git-hooks.hooks.vale.package == vale;
      message = "The Vale hook should use the overridden Vale package.";
    }
    {
      assertion = builtins.elem pkgs.hello config.packages;
      message = "Vale should install the overridden language server package.";
    }
    {
      assertion = !(config.files ? ".vale.ini");
      message = "An explicit config.file without settings must not manage the file.";
    }
  ];

  enterTest = ''
    set -euo pipefail
    test -f synced
    grep -q '^; Existing project configuration' .vale.ini
    test ! -L .vale.ini
  '';
}
