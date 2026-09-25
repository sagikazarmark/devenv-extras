{ config, ... }:

{
  vale = {
    enable = true;
    lsp.enable = false;
  };
  git-hooks.hooks.vale.enable = false;

  enterTest = ''
    set -euo pipefail
    test -z "''${VALE_CONFIG_PATH+x}"
    grep -q '^; Existing project config' .vale.ini
    vale ls-config >/dev/null
    (${config.tasks."devenv:files".exec})
    grep -q '^; Existing project config' .vale.ini
  '';
}
