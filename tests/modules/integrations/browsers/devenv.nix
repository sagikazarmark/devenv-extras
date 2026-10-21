{
  config,
  lib,
  pkgs,
  ...
}:

{
  packages = [
    pkgs.curl
    pkgs.jq
    pkgs.python3
  ];

  browsers = {
    firefox.enable = true;
    chrome.enable = true;
  };

  assertions = [
    {
      assertion =
        config.browsers.chrome.package == (if pkgs.stdenv.isDarwin then pkgs.google-chrome else pkgs.chromium);
      message = "browsers.chrome.package should default to google-chrome on macOS and chromium on Linux.";
    }
    {
      assertion = builtins.all (p: builtins.elem p config.packages) [
        config.browsers.chrome.package
        pkgs.chromedriver
        pkgs.geckodriver
      ];
      message = "browsers should install Chrome, chromedriver and geckodriver.";
    }
    {
      assertion =
        if pkgs.stdenv.isDarwin then
          !(builtins.elem pkgs.firefox config.packages) && lib.any (p: p.name == "firefox") config.packages
        else
          builtins.elem pkgs.firefox config.packages;
      message = "browsers.firefox should install Firefox on Linux, and a launcher on macOS.";
    }
    {
      assertion =
        config.env.FIREFOX_BIN == config.browsers.firefox.executable
        && lib.hasPrefix "${pkgs.firefox}/" config.env.FIREFOX_BIN;
      message = "FIREFOX_BIN should be the Firefox executable.";
    }
    {
      assertion = config.env.CHROME_BIN == lib.getExe config.browsers.chrome.package;
      message = "CHROME_BIN should be the Chrome executable.";
    }
    {
      assertion = !lib.any (lib.hasPrefix "browsers.chrome:") config.warnings;
      message = "browsers.chrome should not warn when chromedriver matches Chrome.";
    }
    {
      assertion = !(config.env ? PLAYWRIGHT_BROWSERS_PATH) && !(config.env ? PUPPETEER_EXECUTABLE_PATH);
      message = "browsers should not configure Playwright or Puppeteer unless enabled.";
    }
  ];
}
