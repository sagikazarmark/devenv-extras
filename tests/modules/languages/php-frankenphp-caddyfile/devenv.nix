{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = toString config.processes.frankenphp.ports.http.value;
in
{
  packages = [
    pkgs.curl
    # The test edits the Caddyfile with GNU sed.
    pkgs.gnused
    pkgs.jq
  ];

  # FrankenPHP's own Caddyfile, unchanged.
  languages.php.frankenphp = {
    enable = true;
    serve = {
      enable = true;
      root = "public";
      caddyfile = "Caddyfile";
    };
  };

  assertions = [
    {
      assertion = config.env.FRANKENPHP_URL == "http://127.0.0.1:${port}";
      message = "FRANKENPHP_URL should point at the frankenphp process.";
    }
    {
      assertion =
        let
          exec = lib.replaceStrings [ "'" ] [ "" ] config.processes.frankenphp.exec;
        in
        lib.hasInfix "frankenphp run --config Caddyfile --adapter caddyfile" exec
        && !lib.hasInfix "--watch" exec;
      message = "The frankenphp process should run the Caddyfile, without Caddy's --watch.";
    }
    {
      assertion = config.processes.frankenphp.watch.paths == [ "${config.devenv.root}/Caddyfile" ];
      message = "devenv should restart the frankenphp process when the Caddyfile changes.";
    }
    {
      assertion =
        let
          env = config.processes.frankenphp.env;
        in
        env.SERVER_NAME == "http://:${port}"
        && env.SERVER_ROOT == "public"
        && env.CADDY_GLOBAL_OPTIONS == "default_bind 127.0.0.1";
      message = "The frankenphp process should set the variables of FrankenPHP's Caddyfile.";
    }
  ];
}
