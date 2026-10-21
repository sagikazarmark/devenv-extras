{
  config,
  lib,
  pkgs,
  ...
}:

{
  packages = [ pkgs.nodejs ];

  browsers.playwright = {
    enable = true;
    browsers = [ "chromium-headless-shell" ];
  };

  assertions = [
    {
      assertion =
        config.browsers.playwright.version == "1.63.0"
        && config.browsers.playwright.package.version == "1.63.0";
      message = "browsers.playwright should install the browsers of playwright-core in package-lock.json.";
    }
    {
      assertion =
        config.env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD == "1"
        && lib.hasPrefix "/nix/store/" config.env.PLAYWRIGHT_BROWSERS_PATH;
      message = "browsers.playwright should point Playwright at the Nix browsers and skip its download.";
    }
    {
      assertion = !lib.any (lib.hasPrefix "browsers.playwright:") config.warnings;
      message = "browsers.playwright should not warn when playwright-driver matches Playwright.";
    }
  ];
}
