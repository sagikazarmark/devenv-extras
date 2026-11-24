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

  languages.php = {
    # Not enabled by default: FrankenPHP should load the extensions of languages.php.
    extensions = [ "shmop" ];
    ini = ''
      memory_limit = 345M
    '';

    frankenphp = {
      enable = true;
      serve = {
        enable = true;
        root = "public";
        # Server only, after languages.php.ini.
        ini = ''
          memory_limit = 456M
        '';
      };
    };
  };

  assertions = [
    {
      assertion = config.env.FRANKENPHP_URL == "http://127.0.0.1:${port}";
      message = "FRANKENPHP_URL should point at the frankenphp process.";
    }
    {
      assertion = config.languages.php.enable;
      message = "languages.php.frankenphp.enable should enable languages.php.";
    }
    {
      assertion = builtins.elem config.languages.php.frankenphp.package config.packages;
      message = "languages.php.frankenphp should install its package.";
    }
    {
      assertion = config.processes.frankenphp.ports.http.allocate == 8000;
      message = "The frankenphp process should listen on a port allocated from 8000.";
    }
    {
      assertion = lib.hasInfix "php-server --listen 127.0.0.1:${port} --root public" (
        lib.replaceStrings [ "'" ] [ "" ] config.processes.frankenphp.exec
      );
      message = "The frankenphp process should run php-server on the allocated port and document root.";
    }
  ];
}
