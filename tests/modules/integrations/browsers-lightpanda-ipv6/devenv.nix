{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = toString config.processes.lightpanda.ports.http.value;
in
{
  packages = [ pkgs.curl ];

  browsers.lightpanda = {
    enable = true;
    serve = {
      enable = true;
      # Bracketed, like in a URL: Lightpanda needs it without brackets.
      host = "[::]";
      protocols = [ "webdriver" ];
    };
  };

  assertions = [
    {
      assertion = lib.hasInfix "--host :: " (
        lib.replaceStrings [ "'" ] [ "" ] config.processes.lightpanda.exec
      );
      message = "browsers.lightpanda.serve.host should be passed to lightpanda serve without brackets.";
    }
    {
      assertion = config.env.LIGHTPANDA_URL == "http://[::1]:${port}";
      message = "LIGHTPANDA_URL should connect to the IPv6 loopback address when the server listens on the IPv6 wildcard.";
    }
    {
      assertion =
        config.processes.lightpanda.ready.http.get.host == "[::1]"
        && config.processes.lightpanda.ready.http.get.path == "/status";
      message = "The lightpanda ready probe should use the IPv6 loopback address, and /status without CDP.";
    }
  ];
}
