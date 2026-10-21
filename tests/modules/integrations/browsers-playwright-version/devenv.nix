{ config, lib, ... }:

{
  browsers.playwright = {
    enable = true;
    # Neither nixpkgs nor nixpkgs-multiverse has 1.61.0, only 1.61.1.
    version = "1.61.0";
    browsers = [ "chromium-headless-shell" ];
  };

  assertions = [
    {
      assertion = config.browsers.playwright.package.version == "1.61.1";
      message = "browsers.playwright should fall back to the newest patch release of the same minor version.";
    }
    {
      assertion = lib.any (lib.hasInfix "playwright-driver 1.61.0 is not packaged") config.warnings;
      message = "browsers.playwright should warn when it falls back to another patch release.";
    }
  ];
}
