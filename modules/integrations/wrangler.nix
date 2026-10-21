{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.wrangler;

  # Default ports count up from wrangler's own in the order of the workers, so they also differ with strict ports.
  workerIndex = name: lib.lists.findFirstIndex (n: n == name) 0 (lib.attrNames cfg.dev);

  workerBuild = config.worker-build;

  # worker-build downloads these unless they are set. wasm-bindgen must match the crate, so it is only set
  # when its version is known from Cargo.lock; otherwise worker-build downloads the matching version.
  workerBuildEnv = lib.optionalAttrs workerBuild.enable (
    {
      ESBUILD_BIN = lib.getExe workerBuild.esbuild.package;
      WASM_OPT_BIN = lib.getExe' workerBuild.wasm-opt.package "wasm-opt";
    }
    // lib.optionalAttrs (workerBuild.wasm-bindgen.version != null) {
      WASM_BINDGEN_BIN = lib.getExe' workerBuild.wasm-bindgen.package "wasm-bindgen";
    }
  );

  wrangler = lib.getExe cfg.package;
  curl = lib.getExe pkgs.curl;

  # Wildcard addresses are fine to bind to, but not to connect to.
  connectHost =
    host:
    if
      builtins.elem host [
        "0.0.0.0"
        "::"
        "[::]"
      ]
    then
      "127.0.0.1"
    else if lib.hasInfix ":" host && !lib.hasPrefix "[" host then
      "[${host}]"
    else
      host;

  # Arguments that select the worker, shared by `wrangler dev` and the migrations.
  workerArgs =
    worker:
    [
      "--cwd"
      "${config.devenv.root}/${worker.directory}"
    ]
    ++ lib.optionals (worker.config != null) [
      "--config"
      worker.config
    ];

  envArgs =
    worker:
    lib.optionals (worker.environment != null) [
      "--env"
      worker.environment
    ];

  # Workers that keep their local data in the same directory as the given one, itself included.
  sharing = worker: lib.filterAttrs (_: other: other.persistTo == worker.persistTo) cfg.dev;

  migrateTask = name: "devenv:wrangler:migrate-${name}";

  migrateCommand =
    worker: database:
    "${wrangler} ${
      lib.escapeShellArgs (
        workerArgs worker
        ++ [
          "d1"
          "migrations"
          "apply"
          database
          "--local"
          "--persist-to"
          worker.persistTo
        ]
        ++ envArgs worker
      )
    }";

  devModule =
    { name, ... }@args:
    let
      worker = args.config;
    in
    {
      options = {
        directory = lib.mkOption {
          type = lib.types.str;
          default = name;
          defaultText = lib.literalMD "the name of the worker";
          example = "workers/api";
          description = ''
            The directory of the worker, relative to the project root.
            Wrangler runs there (with `--cwd`), so its configuration and custom build work unchanged.
          '';
        };

        config = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "wrangler.dev.toml";
          description = ''
            The Wrangler configuration file, relative to `directory`.
            When null, Wrangler finds `wrangler.toml`, `wrangler.json` or `wrangler.jsonc` itself.
          '';
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          example = "0.0.0.0";
          description = "The address the worker listens on.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 8787 + workerIndex name;
          defaultText = lib.literalMD "8787, plus the position of the worker in `wrangler.dev`";
          description = ''
            The base port the worker listens on.
            The actual port is allocated by devenv and may differ;
            `config.processes."wrangler-<name>".ports.http.value` has it.
          '';
        };

        inspectorPort = lib.mkOption {
          type = lib.types.port;
          default = 9229 + workerIndex name;
          defaultText = lib.literalMD "9229, plus the position of the worker in `wrangler.dev`";
          description = ''
            The base port for the devtools inspector.
            The actual port is allocated by devenv and may differ.
          '';
        };

        environment = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "dev";
          description = ''
            The Wrangler environment to use (`--env`), for `wrangler dev` and the D1 migrations.
            Wrangler names the worker `<name>-<environment>`, so service bindings and `script_name`
            in other workers have to use that name.
          '';
        };

        vars = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = lib.literalExpression ''
            {
              PUBLIC_URL = config.wrangler.dev.app.url;
            }
          '';
          description = ''
            Variables for the worker, passed with `--var`.
            They take precedence over `vars` in the Wrangler configuration and over `.dev.vars` and `.env` files.
          '';
        };

        persistTo = lib.mkOption {
          type = lib.types.str;
          default = "${config.devenv.state}/wrangler/state/${name}";
          defaultText = lib.literalExpression ''"''${config.devenv.state}/wrangler/state/<name>"'';
          description = ''
            The directory for the local data of the worker, such as D1, KV and R2 (`--persist-to`).
            D1 migrations use it as well.

            Workers with the same directory share data with the same IDs, such as a D1 database.
            Wrangler does not support this across `wrangler dev` sessions, and they crash when they open
            the directory at the same time, so these workers start one after the other, each when the one before it is ready.
            Concurrent writes to the same database may still fail with `SQLITE_BUSY`.
          '';
        };

        ready.path = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "/cdn-cgi/local/platform-proxy";
          example = "/healthz";
          description = ''
            The path to request to check that the worker is ready.
            Any HTTP response means ready: `wrangler dev` holds requests until the worker is built and running.
            The default is handled by Wrangler itself, without running the worker.
            When null, devenv only checks that the port accepts connections, which happens before the worker is built.
          '';
        };

        d1.migrate = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "DB" ];
          description = ''
            D1 databases of the worker to apply migrations to, by binding or database name,
            before the workers using its `persistTo` directory start.
            Wrangler reads the migrations from the `migrations_dir` of the database in the configuration of the worker.
          '';
        };

        url = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "http://${connectHost worker.host}:${
            toString config.processes."wrangler-${name}".ports.http.value
          }";
          defaultText = lib.literalMD "the local URL of the worker, with the port allocated by devenv";
          description = "The local URL of the worker.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "--log-level"
            "debug"
          ];
          description = "More arguments for `wrangler dev`.";
        };
      };
    };
in
{
  options.wrangler = {
    enable = lib.mkEnableOption "Wrangler, the Cloudflare Workers CLI";

    package = lib.mkPackageOption pkgs "wrangler" { };

    registry = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "${config.devenv.state}/wrangler/registry";
      defaultText = lib.literalExpression ''"''${config.devenv.state}/wrangler/registry"'';
      description = ''
        The dev registry `wrangler dev` sessions use to find each other, for service bindings,
        Durable Objects and tail consumers across workers. It is exported as `WRANGLER_REGISTRY_PATH`.
        The default keeps the workers of this project apart from those of others;
        null uses Wrangler's global registry.
      '';
    };

    dev = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule devModule);
      default = { };
      example = lib.literalExpression ''
        {
          api = { };
          app.directory = "workers/app";
        }
      '';
      description = ''
        Workers to run with `wrangler dev`, each in a `wrangler-<name>` process.
        Each runs in its own session, and the sessions reach each other through the dev registry.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package ];

    env = lib.optionalAttrs (cfg.registry != null) {
      WRANGLER_REGISTRY_PATH = cfg.registry;
    };

    assertions = lib.concatLists (
      lib.mapAttrsToList (name: worker: [
        {
          assertion = lib.hasPrefix "/" worker.persistTo;
          message = "wrangler.dev.${name}.persistTo must be an absolute path.";
        }
        {
          assertion = worker.ready.path == null || lib.hasPrefix "/" worker.ready.path;
          message = "wrangler.dev.${name}.ready.path must start with a slash.";
        }
        {
          assertion = !lib.any (lib.hasInfix ":") (lib.attrNames worker.vars);
          message = "wrangler.dev.${name}.vars names must not contain a colon: Wrangler splits `--var` at the first one.";
        }
      ]) cfg.dev
    );

    processes = lib.mapAttrs' (
      name: worker:
      lib.nameValuePair "wrangler-${name}" {
        exec = "exec ${wrangler} ${
          lib.escapeShellArgs (
            workerArgs worker
            ++ [
              "dev"
              "--ip"
              worker.host
              "--port"
              (toString config.processes."wrangler-${name}".ports.http.value)
              "--inspector-port"
              (toString config.processes."wrangler-${name}".ports.inspector.value)
              "--persist-to"
              worker.persistTo
              # The process manager owns the terminal.
              "--show-interactive-dev-session=false"
            ]
            ++ envArgs worker
            ++ lib.concatLists (
              lib.mapAttrsToList (key: value: [
                "--var"
                "${key}:${value}"
              ]) worker.vars
            )
            ++ worker.extraArgs
          )
        }";

        env = workerBuildEnv;

        # Workers sharing a directory crash when they open its databases at the same time,
        # so each one starts when the one before it is ready.
        after =
          let
            earlier = lib.filter (other: other < name) (lib.attrNames (sharing worker));
          in
          lib.optional (earlier != [ ]) "devenv:processes:wrangler-${lib.last earlier}";

        ports.http.allocate = worker.port;
        ports.inspector.allocate = worker.inspectorPort;

        # wrangler dev accepts connections before the worker is built, and holds requests until it runs.
        ready = lib.mkIf (worker.ready.path != null) {
          exec = lib.mkDefault "${curl} --silent --output /dev/null --max-time 1 ${lib.escapeShellArg "${worker.url}${worker.ready.path}"}";
          period = lib.mkDefault 1;
          probe_timeout = lib.mkDefault 2;
        };
      }
    ) cfg.dev;

    tasks = lib.mapAttrs' (
      name: worker:
      let
        sharers = sharing worker;
      in
      lib.nameValuePair (migrateTask name) {
        description = "Apply the D1 migrations of the ${name} worker";
        exec = lib.concatMapStringsSep " && " (migrateCommand worker) worker.d1.migrate;
        # Migrations for the same directory run one at a time, in the order of the workers.
        after = map migrateTask (
          lib.filter (other: other < name && sharers.${other}.d1.migrate != [ ]) (lib.attrNames sharers)
        );
        before = map (other: "devenv:processes:wrangler-${other}") (lib.attrNames sharers);
      }
    ) (lib.filterAttrs (_: worker: worker.d1.migrate != [ ]) cfg.dev);
  };
}
