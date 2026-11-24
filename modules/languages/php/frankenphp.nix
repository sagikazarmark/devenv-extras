{
  pkgs,
  config,
  lib,
  ...
}:

let
  php = config.languages.php;
  cfg = php.frankenphp;

  # An extension of a PHP package set by its name, or null. The attribute name is the extension
  # name for all but a few extensions.
  findExtension =
    extensions: name:
    extensions.${name}
      or (lib.findFirst (
        candidate: (builtins.tryEval (candidate.extensionName or null)).value == name
      ) null (builtins.attrValues extensions));

  # The PHP that FrankenPHP embeds, which extensions have to be built for.
  ztsPhp = defaultPackage.php.unwrapped;

  # FrankenPHP rebuilds PHP with thread safety (ZTS), which rebuilds the extensions its extension
  # functions take from `all`. devenv's `languages.php.extensions` come from the original PHP
  # package instead, and a ZTS PHP cannot load them.
  #
  # Swap the extensions of the original package for their ZTS builds, and keep the others, such
  # as patched ones built from `all`. Internal and PECL extensions are built with their PHP as a
  # native build input: one built for another PHP cannot be rebuilt, so it fails evaluation.
  #
  # Derivations are compared by their derivation paths: `==` does not compare them by their outputs.
  rebuildExtension =
    all: extension:
    let
      name = extension.extensionName;
      original = findExtension php.package.extensions name;
      builtForOtherPhp = lib.any (
        input: (input.pname or null) == "php" && input.drvPath != ztsPhp.drvPath
      ) (extension.nativeBuildInputs or [ ]);
    in
    if original != null && extension.drvPath == original.drvPath then
      lib.defaultTo extension (findExtension all name)
    else if builtForOtherPhp then
      throw ''
        languages.php.frankenphp: the PHP extension ${name} is built for another PHP than the thread
        safe one FrankenPHP embeds. Take it from the `all` argument of the extensions function of
        languages.php.package, so that it is rebuilt for FrankenPHP, or set
        languages.php.frankenphp.package.
      ''
    else
      extension;

  # The `extraConfig` of the original package is kept by `override`.
  frankenphpPhp = php.package.override (args: {
    extensions =
      { all, enabled }:
      map (rebuildExtension all) (
        (args.extensions or ({ enabled, ... }: enabled)) { inherit all enabled; }
      );
  });

  defaultPackage = pkgs.frankenphp.override { php = frankenphpPhp; };

  port = config.processes.frankenphp.ports.http.value;

  # Caddy only accepts IPv6 addresses in brackets.
  urlHost =
    if lib.hasInfix ":" cfg.serve.host && !lib.hasPrefix "[" cfg.serve.host then
      "[${cfg.serve.host}]"
    else
      cfg.serve.host;

  connectHost =
    if cfg.serve.host == "0.0.0.0" then
      "127.0.0.1"
    else if urlHost == "[::]" then
      "[::1]"
    else
      urlHost;

  url = "http://${connectHost}:${toString port}";

  stateDir = "${config.devenv.state}/frankenphp";

  serveIni = pkgs.writeTextDir "frankenphp-serve.ini" cfg.serve.ini;

  worker = cfg.serve.worker;

  caddyfile = cfg.serve.caddyfile;

  serveArgs =
    if caddyfile != null then
      [
        "run"
        "--config"
        caddyfile
        "--adapter"
        "caddyfile"
      ]
    else
      [
        "php-server"
        "--listen"
        "${urlHost}:${toString port}"
        "--root"
        cfg.serve.root
      ]
      ++ lib.optionals (worker.file != null) (
        [
          "--worker"
          (worker.file + lib.optionalString (worker.count != null) ",${toString worker.count}")
        ]
        # `--watch` takes an optional value, which only `=` passes.
        ++ map (pattern: "--watch=${pattern}") worker.watch
      );

  # The variables FrankenPHP's own Caddyfile reads, for the address and document root.
  caddyfileEnv = {
    # devenv's proxy keeps the Host header of the request, so the site matches any host, like
    # `php-server`, and `default_bind` sets the address.
    SERVER_NAME = "http://:${toString port}";
    SERVER_ROOT = cfg.serve.root;
    CADDY_GLOBAL_OPTIONS = "default_bind ${lib.removePrefix "[" (lib.removeSuffix "]" cfg.serve.host)}";
    # `frankenphp run` serves Caddy's admin API, on port 2019 by default: a socket does not clash
    # with other projects. Unix socket paths are short, so it is in the runtime directory.
    CADDY_ADMIN = "unix/${config.env.DEVENV_RUNTIME}/frankenphp-admin.sock";
  };
in
{
  options.languages.php.frankenphp = {
    enable = lib.mkEnableOption "FrankenPHP, the PHP app server built on Caddy";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalMD "`pkgs.frankenphp`, built with `languages.php.package`";
      description = ''
        The FrankenPHP package. FrankenPHP embeds PHP, so by default it is built with
        `languages.php.package`: it loads the same extensions and `php.ini` directives.

        FrankenPHP needs a thread safe (ZTS) build of PHP with the embed SAPI, which the package
        builds from `languages.php.package`, with its extensions. The FrankenPHP binary is built
        locally, and so are extensions that nixpkgs' FrankenPHP does not load by default.

        Extensions that `languages.php.package` takes from the `all` argument of its extensions
        function are rebuilt for FrankenPHP's PHP, with their changes, such as `overrideAttrs`.
        An extension built for another PHP, such as from `pkgs.php.extensions`, fails evaluation.
      '';
    };

    serve = {
      enable = lib.mkEnableOption "a `frankenphp` process that runs `frankenphp php-server`";

      root = lib.mkOption {
        type = lib.types.str;
        default = ".";
        example = "public";
        description = "The document root, relative to the devenv root.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "The address the server listens on.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8000;
        description = ''
          The base port the server listens on, over HTTP.
          The port is allocated from it, and `config.processes.frankenphp.ports.http.value` has it.
        '';
      };

      ini = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = ''
          display_errors = On
          opcache.validate_timestamps = 1
        '';
        description = ''
          `php.ini` directives for the server only, after those of `languages.php.ini`, like
          `languages.php.fpm.phpOptions` for PHP-FPM. They do not rebuild FrankenPHP.
        '';
      };

      worker = {
        file = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "public/index.php";
          description = ''
            The worker script, relative to the devenv root. When set, the server runs in
            [worker mode](https://frankenphp.dev/docs/worker/): the script boots the application
            once and handles requests in a loop with `frankenphp_handle_request()`.
          '';
        };

        count = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = null;
          description = "The number of workers to start. When null, FrankenPHP starts two per CPU.";
        };

        watch = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "./**/*.{env,php,twig,yaml,yml}" ];
          example = [
            "./src/**/*.php"
            "./config/**/*.yaml"
          ];
          description = ''
            Glob patterns of files that restart the workers when they change, relative to the devenv
            root. A worker keeps the code it booted with, so the default is FrankenPHP's pattern for
            `--watch`. Set to `[ ]` to disable watching.
          '';
        };
      };

      caddyfile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "Caddyfile";
        description = ''
          A Caddyfile to run with `frankenphp run` instead of `frankenphp php-server`, relative to
          the devenv root. devenv restarts the server when it changes, unless it is in the Nix store.

          The process sets the environment variables that
          [FrankenPHP's Caddyfile](https://github.com/php/frankenphp/blob/main/caddy/frankenphp/Caddyfile)
          reads, so it works as it is: `SERVER_NAME` (`http://:<port>`, for any host), `SERVER_ROOT`
          (`root`), and `CADDY_GLOBAL_OPTIONS` (`default_bind <host>`). Your own Caddyfile should
          serve `{$SERVER_NAME}` too, for `FRANKENPHP_URL` and the readiness check. Override these in
          `processes.frankenphp.env`, which also sets variables such as `FRANKENPHP_CONFIG`.

          Caddy's admin API listens on a Unix socket, `CADDY_ADMIN`. Configure workers in the
          Caddyfile, not with `worker`.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "--access-log" ];
        description = "More arguments for `frankenphp php-server`, or `frankenphp run` with `caddyfile`.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      languages.php.enable = lib.mkDefault true;

      packages = [ cfg.package ];
    })

    (lib.mkIf (cfg.enable && cfg.serve.enable) {
      env.FRANKENPHP_URL = url;

      assertions = [
        {
          assertion = caddyfile == null || worker.file == null;
          message = "languages.php.frankenphp.serve.worker does not apply to serve.caddyfile: configure workers in the Caddyfile.";
        }
      ];

      processes.frankenphp = {
        env = lib.mkIf (caddyfile != null) (lib.mapAttrs (_: lib.mkDefault) caddyfileEnv);

        # Restart the server when the Caddyfile changes. Caddy's `--watch` polls the Caddyfile and
        # adapts it every second, logging its warnings each time.
        watch.paths = lib.optional (caddyfile != null && !lib.hasPrefix builtins.storeDir caddyfile) (
          if lib.hasPrefix "/" caddyfile then caddyfile else "${config.devenv.root}/${caddyfile}"
        );

        # Caddy keeps its state in the XDG directories.
        exec = ''
          export XDG_CONFIG_HOME=${lib.escapeShellArg "${stateDir}/config"}
          export XDG_DATA_HOME=${lib.escapeShellArg "${stateDir}/data"}
          ${lib.optionalString (cfg.serve.ini != "") ''
            # PHP reads the scan directories in order, so the server's directives come last.
            export PHP_INI_SCAN_DIR="''${PHP_INI_SCAN_DIR:-${cfg.package}/lib}:${serveIni}"
          ''}
          exec ${lib.getExe cfg.package} ${lib.escapeShellArgs (serveArgs ++ cfg.serve.extraArgs)}
        '';

        cwd = config.devenv.root;

        ports.http.allocate = cfg.serve.port;

        # Any response will do: the site does not need to serve `/` successfully.
        ready.exec = "${lib.getExe pkgs.curl} --silent --globoff --output /dev/null ${lib.escapeShellArg "${url}/"}";
      };
    })
  ];
}
