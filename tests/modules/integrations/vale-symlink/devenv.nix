{ ... }:

{
  vale = {
    enable = true;
    lsp.enable = false;
    config.copyMode = "symlink";
    config.settings.sections."*.md".BasedOnStyles = "Vale";
  };
  git-hooks.hooks.vale.enable = false;

  enterTest = ''
    set -euo pipefail
    test -L .vale.ini
    test "$VALE_CONFIG_PATH" = "$DEVENV_ROOT/.vale.ini"
    vale ls-config >/dev/null
  '';
}
