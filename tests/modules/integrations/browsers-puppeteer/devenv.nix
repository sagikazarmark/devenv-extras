{
  config,
  lib,
  pkgs,
  ...
}:

{
  packages = [ pkgs.nodejs ];

  browsers.puppeteer = {
    enable = true;
    browser = "firefox";
  };

  assertions = [
    {
      assertion = config.browsers.firefox.enable && !config.browsers.chrome.enable;
      message = "browsers.puppeteer should enable only its browser.";
    }
    {
      assertion =
        config.env.PUPPETEER_BROWSER == "firefox"
        && config.env.PUPPETEER_EXECUTABLE_PATH == config.browsers.firefox.executable
        && config.env.PUPPETEER_SKIP_DOWNLOAD == "true";
      message = "browsers.puppeteer should point Puppeteer at Firefox and skip its download.";
    }
  ];
}
