{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Stand-ins, so the fixture does not download browsers.
  fakeChrome = pkgs.writeShellScriptBin "chrome" "echo Chrome 150.0.1" // {
    version = "150.0.1";
  };
  fakeChromedriver = pkgs.writeShellScriptBin "chromedriver" "echo ChromeDriver 149.0.1" // {
    version = "149.0.1";
  };
in
{
  # This fixture has no nixpkgs-multiverse input: nothing here may resolve through it.
  browsers = {
    chrome = {
      enable = true;
      package = fakeChrome;
      driver.package = fakeChromedriver;
    };

    firefox = {
      enable = true;
      package = pkgs.hello;
      executable = lib.getExe pkgs.hello;
      driver.enable = false;
    };

    # Not enabled: only its version is read.
    playwright.packageLock = ./e2e/package-lock.json;
  };

  assertions = [
    {
      assertion = config.env.CHROME_BIN == "${fakeChrome}/bin/chrome";
      message = "CHROME_BIN should be the executable of browsers.chrome.package.";
    }
    {
      assertion = lib.any (lib.hasInfix "chromedriver 149.0.1 does not support Chrome 150.0.1") config.warnings;
      message = "browsers.chrome should warn when chromedriver does not match the major version of Chrome.";
    }
    {
      assertion = config.env.FIREFOX_BIN == lib.getExe pkgs.hello;
      message = "browsers.firefox.executable should set FIREFOX_BIN.";
    }
    {
      assertion = !(builtins.elem pkgs.geckodriver config.packages);
      message = "browsers.firefox.driver.enable = false should not install geckodriver.";
    }
    {
      assertion = config.browsers.playwright.version == "1.60.0";
      message = "browsers.playwright.version should be read from a workspace in package-lock.json.";
    }
    {
      assertion = !(config.env ? PLAYWRIGHT_BROWSERS_PATH);
      message = "browsers.playwright should not set PLAYWRIGHT_BROWSERS_PATH unless enabled.";
    }
  ];
}
