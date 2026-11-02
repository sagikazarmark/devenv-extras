{
  config,
  lib,
  pkgs,
  ...
}:

let
  sitePort = toString config.processes.site.ports.http.value;
  lightpandaPort = toString config.processes.lightpanda.ports.http.value;
in
{
  packages = [
    pkgs.curl
    pkgs.jq
    pkgs.nodejs
    pkgs.python3
  ];

  browsers.lightpanda = {
    enable = true;
    serve = {
      enable = true;
      protocols = [
        "cdp"
        "webdriver"
      ];
    };
  };

  # The page the browser opens, served over HTTP like an app under test.
  processes.site = {
    exec = "exec python3 -m http.server --bind 127.0.0.1 ${sitePort}";
    cwd = "${config.devenv.root}/site";
    ports.http.allocate = 8000;
  };

  env.SITE_URL = "http://127.0.0.1:${sitePort}/";

  assertions = [
    {
      assertion = config.browsers.lightpanda.package.pname == "lightpanda-bin";
      message = "browsers.lightpanda.package should default to lightpanda-bin, without an overlay.";
    }
    {
      assertion = builtins.elem config.browsers.lightpanda.package config.packages;
      message = "browsers.lightpanda should install its package.";
    }
    {
      assertion = config.env.LIGHTPANDA_DISABLE_TELEMETRY == "true";
      message = "browsers.lightpanda should disable telemetry by default.";
    }
    {
      assertion =
        config.processes.lightpanda.ports.http.allocate == 9222
        && config.env.LIGHTPANDA_URL == "http://127.0.0.1:${lightpandaPort}";
      message = "LIGHTPANDA_URL should point at the lightpanda process, on a port allocated from 9222.";
    }
    {
      assertion = lib.hasInfix "--protocol cdp --protocol webdriver" (
        lib.replaceStrings [ "'" ] [ "" ] config.processes.lightpanda.exec
      );
      message = "browsers.lightpanda.serve.protocols should be passed to lightpanda serve.";
    }
  ];
}
