{
  pkgs,
  config,
  lib,
  multiverse,
  ...
}:

let
  cfg = config.browsers;

  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  versions = import ../lib/versions.nix {
    inherit
      pkgs
      lib
      config
      multiverse
      ;
  };

  # On macOS, nixpkgs Firefox is an app bundle without a bin directory.
  firefoxLauncher = pkgs.writeShellScriptBin "firefox" ''
    exec ${lib.escapeShellArg cfg.firefox.executable} "$@"
  '';

  # A package's major version, or null without a version.
  majorVersion = package: if package ? version then lib.versions.major package.version else null;

  chromeDriverMismatch =
    let
      chrome = majorVersion cfg.chrome.package;
      driver = majorVersion cfg.chrome.driver.package;
    in
    cfg.chrome.driver.enable && chrome != null && driver != null && chrome != driver;

  # playwright-driver at `version`: from nixpkgs if it has it, otherwise from nixpkgs-multiverse.
  # Without that exact version, the newest patch release of the same minor version.
  playwrightDriver =
    version:
    let
      nixpkgsVersion = pkgs.playwright-driver.version;
      multiverseVersions = versions.multiverseVersions "playwright-driver";

      sameMinor = lib.filter (v: lib.versions.majorMinor v == lib.versions.majorMinor version) (
        lib.unique ([ nixpkgsVersion ] ++ multiverseVersions)
      );
      newest = lib.foldl' (a: b: if a == null || lib.versionOlder a b then b else a) null sameMinor;

      package =
        v:
        if v == nixpkgsVersion then
          pkgs.playwright-driver
        else
          versions.fromMultiverse "playwright-driver" v;
    in
    if version == null then
      pkgs.playwright-driver
    else if version == nixpkgsVersion || lib.elem version multiverseVersions then
      package version
    else if newest != null then
      package newest
    else if multiverseVersions == [ ] then
      throw ''
        browsers.playwright: nixpkgs has playwright-driver ${nixpkgsVersion}, not ${version}.
        Other versions come from nixpkgs-multiverse, which needs the input:

          devenv inputs add nixpkgs-multiverse github:fzakaria/nixpkgs-multiverse
      ''
    else
      throw ''
        browsers.playwright: neither nixpkgs nor nixpkgs-multiverse has playwright-driver ${lib.versions.majorMinor version}.x.
        Set browsers.playwright.package to a playwright-driver package.
      '';

  # The Playwright browsers to install, with the flags of playwright-driver's `selectBrowsers`.
  playwrightBrowserFlags = {
    chromium = "withChromium";
    chromium-headless-shell = "withChromiumHeadlessShell";
    firefox = "withFirefox";
    webkit = "withWebkit";
    ffmpeg = "withFfmpeg";
  };

  playwrightBrowsers =
    let
      driver = cfg.playwright.package;
      selectBrowsers =
        driver.selectBrowsers
          or (throw "browsers.playwright: playwright-driver ${driver.version} cannot select browsers. Set browsers.playwright.browsers to null.");
      # Older playwright-driver versions support fewer flags.
      supported = lib.functionArgs selectBrowsers;
      flags = lib.mapAttrs' (
        browser: flag: lib.nameValuePair flag (lib.elem browser cfg.playwright.browsers)
      ) playwrightBrowserFlags;
    in
    if cfg.playwright.browsers == null then
      driver.browsers
    else
      selectBrowsers (lib.filterAttrs (flag: _: supported ? ${flag}) flags);

  playwrightWarnings =
    let
      version = cfg.playwright.version;
      driverVersion = cfg.playwright.package.version;
    in
    lib.optional (version != null && driverVersion != version) (
      if lib.versions.majorMinor driverVersion != lib.versions.majorMinor version then
        ''
          browsers.playwright: the browsers are from playwright-driver ${driverVersion}, but Playwright is ${version}.
          Playwright finds browsers by revision, which changes between minor versions, so it will not find them.
        ''
      else
        ''
          browsers.playwright: playwright-driver ${version} is not packaged, so the browsers are from ${driverVersion}.
          Playwright finds browsers by revision, which usually changes only between minor versions.
        ''
    );
in
{
  options.browsers = {
    firefox = {
      enable = lib.mkEnableOption "Firefox and geckodriver, its WebDriver server";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.firefox;
        defaultText = lib.literalExpression "pkgs.firefox";
        description = "The Firefox package.";
      };

      executable = lib.mkOption {
        type = lib.types.str;
        default =
          if isDarwin then
            "${cfg.firefox.package}/Applications/Firefox.app/Contents/MacOS/firefox"
          else
            lib.getExe cfg.firefox.package;
        defaultText = lib.literalMD "the `firefox` executable of `package`, in `Firefox.app` on macOS";
        description = ''
          The Firefox executable, exported as `FIREFOX_BIN`.
          On macOS, where nixpkgs Firefox is an app bundle, a `firefox` command that runs it is installed.
        '';
      };

      driver = {
        enable = lib.mkEnableOption "geckodriver" // {
          default = true;
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.geckodriver;
          defaultText = lib.literalExpression "pkgs.geckodriver";
          description = "The geckodriver package.";
        };
      };
    };

    chrome = {
      enable = lib.mkEnableOption "Chrome (Chromium on Linux) and chromedriver, its WebDriver server";

      package = lib.mkOption {
        type = lib.types.package;
        default = if isDarwin then pkgs.google-chrome else pkgs.chromium;
        defaultText = lib.literalMD "`pkgs.google-chrome` on macOS, `pkgs.chromium` on Linux";
        description = ''
          The Chrome package.

          nixpkgs only builds Chromium for Linux, so macOS defaults to Google Chrome, which is unfree:
          allow it with `nixpkgs.permitted_unfree_packages: [ google-chrome ]` in `devenv.yaml`.
        '';
      };

      executable = lib.mkOption {
        type = lib.types.str;
        default = lib.getExe cfg.chrome.package;
        defaultText = lib.literalExpression "lib.getExe config.browsers.chrome.package";
        description = "The Chrome executable, exported as `CHROME_BIN`.";
      };

      driver = {
        enable = lib.mkEnableOption "chromedriver" // {
          default = true;
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.chromedriver;
          defaultText = lib.literalExpression "pkgs.chromedriver";
          description = ''
            The chromedriver package. chromedriver only supports the Chrome version with the same major version,
            and devenv warns when they differ.
          '';
        };
      };
    };

    playwright = {
      enable = lib.mkEnableOption "browsers for Playwright, instead of the ones it downloads";

      packageLock = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          The package-lock.json to read the `playwright-core` version from.
          When null, package-lock.json at the project root is used if it exists.
        '';
      };

      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = versions.npmLockedVersion cfg.playwright.packageLock "playwright-core";
        defaultText = lib.literalMD "the version of `playwright-core` in package-lock.json, or null";
        description = ''
          The Playwright version to install browsers for. Playwright only finds the browsers of its own version.
          Defaults to the version of `playwright-core` (which `playwright` and `@playwright/test` depend on)
          in package-lock.json, if there is one.

          The browsers come from `playwright-driver` at this version: from nixpkgs if it has it, otherwise from
          nixpkgs-multiverse, which needs the `nixpkgs-multiverse` input. When neither has it, they come from the
          newest patch release of the same minor version, and devenv warns. When null,
          `pkgs.playwright-driver` is installed.
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = playwrightDriver cfg.playwright.version;
        defaultText = lib.literalMD "`playwright-driver` at `version`, or `pkgs.playwright-driver`";
        description = "The playwright-driver package to take the browsers from. Setting it overrides `version`.";
      };

      browsers = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf (lib.types.enum (lib.attrNames playwrightBrowserFlags)));
        default = null;
        example = [ "chromium-headless-shell" ];
        description = ''
          The browsers to install. When null, all the browsers of `package` are installed.
          Headless Chromium runs `chromium-headless-shell`, and `ffmpeg` records videos.
        '';
      };
    };

    puppeteer = {
      enable = lib.mkEnableOption "a browser for Puppeteer, instead of the one it downloads";

      browser = lib.mkOption {
        type = lib.types.enum [
          "chrome"
          "firefox"
        ];
        default = "chrome";
        description = ''
          The browser Puppeteer launches. Its `browsers.<name>.enable` defaults to true.
          Puppeteer is tested with one Chrome version, but other recent versions usually work.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.firefox.enable {
      packages = [
        (if isDarwin then firefoxLauncher else cfg.firefox.package)
      ]
      ++ lib.optional cfg.firefox.driver.enable cfg.firefox.driver.package;

      env.FIREFOX_BIN = cfg.firefox.executable;
    })

    (lib.mkIf cfg.chrome.enable {
      packages = [ cfg.chrome.package ] ++ lib.optional cfg.chrome.driver.enable cfg.chrome.driver.package;

      env.CHROME_BIN = cfg.chrome.executable;

      warnings = lib.optional chromeDriverMismatch ''
        browsers.chrome: chromedriver ${cfg.chrome.driver.package.version} does not support Chrome ${cfg.chrome.package.version}.
        Set browsers.chrome.driver.package to chromedriver ${majorVersion cfg.chrome.package}, or browsers.chrome.driver.enable = false.
      '';
    })

    (lib.mkIf cfg.playwright.enable {
      env = {
        PLAYWRIGHT_BROWSERS_PATH = toString playwrightBrowsers;
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        # Playwright checks for system libraries that Nix provides differently.
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      };

      warnings = playwrightWarnings;
    })

    {
      browsers.chrome.enable = lib.mkIf (cfg.puppeteer.enable && cfg.puppeteer.browser == "chrome") (
        lib.mkDefault true
      );
      browsers.firefox.enable = lib.mkIf (cfg.puppeteer.enable && cfg.puppeteer.browser == "firefox") (
        lib.mkDefault true
      );
    }

    (lib.mkIf cfg.puppeteer.enable {
      env = {
        PUPPETEER_BROWSER = cfg.puppeteer.browser;
        PUPPETEER_EXECUTABLE_PATH = cfg.${cfg.puppeteer.browser}.executable;
        PUPPETEER_SKIP_DOWNLOAD = "true";
      };

      assertions = [
        {
          assertion = cfg.${cfg.puppeteer.browser}.enable;
          message = "browsers.puppeteer.browser is ${cfg.puppeteer.browser}, which needs browsers.${cfg.puppeteer.browser}.enable.";
        }
      ];
    })
  ];
}
