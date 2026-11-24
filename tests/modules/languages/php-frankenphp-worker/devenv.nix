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
    pkgs.jq
  ];

  languages.php.frankenphp = {
    enable = true;
    serve = {
      enable = true;
      root = "public";
      worker = {
        file = "public/index.php";
        # One worker, so every request reaches the same one.
        count = 1;
      };
    };
  };

  assertions = [
    {
      assertion = config.env.FRANKENPHP_URL == "http://127.0.0.1:${port}";
      message = "FRANKENPHP_URL should point at the frankenphp process.";
    }
    {
      assertion = lib.hasInfix "--worker public/index.php,1 --watch=./**/*.{env,php,twig,yaml,yml}" (
        lib.replaceStrings [ "'" ] [ "" ] config.processes.frankenphp.exec
      );
      message = "The frankenphp process should run the worker and watch FrankenPHP's default pattern.";
    }
    {
      assertion = !lib.hasInfix "PHP_INI_SCAN_DIR" config.processes.frankenphp.exec;
      message = "The frankenphp process should only set PHP_INI_SCAN_DIR for languages.php.frankenphp.serve.ini.";
    }
  ];
}
