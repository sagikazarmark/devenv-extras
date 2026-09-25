{ config, ... }:

{
  vale = {
    enable = true;
    lsp.enable = false;
    sync.enable = true;
  };
  git-hooks.hooks.vale.enable = false;

  assertions = [
    {
      assertion = config.vale.config.file == null && !(config.env ? VALE_CONFIG_PATH);
      message = "Vale discovery must not set a config path or environment override.";
    }
    {
      assertion = config.git-hooks.hooks.vale.settings.configPath == "";
      message = "The Vale hook must leave configuration discovery enabled.";
    }
  ];

  enterTest = ''
    set -euo pipefail
    test -f .vale.ini
    grep -q '^Packages=Microsoft$' .vale.ini
    test -f vale.ini
    test -z "''${VALE_CONFIG_PATH+x}"
    test -d "$VALE_STYLES_PATH"
    # Explicit INI paths override the environment for sync destinations.
    test -f project-styles/Local/Forbidden.yml
    test ! -e "$VALE_STYLES_PATH/Local"
    printf 'BADWORD\n' > bad.md
    mkdir nested
    if (cd nested && vale ../bad.md) > alerts.txt; then
      echo 'Discovered Vale configuration should reject BADWORD' >&2
      exit 1
    fi
    grep -q 'Local.Forbidden' alerts.txt
    test -f Local/Forbidden.yml
  '';
}
