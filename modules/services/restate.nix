{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.restate;

  settingsFormat = pkgs.formats.toml { };

  restate = lib.getExe' cfg.package "restate";
  restateServer = lib.getExe' cfg.package "restate-server";
  curl = lib.getExe pkgs.curl;

  # tasks.*.wantedBy requires devenv 2.3.2 or newer.
  cliVersion = config.devenv.cli.version or null;
  supportsWantedBy = cliVersion == null || lib.versionAtLeast cliVersion "2.3.2";

  ingressPort = config.processes.restate.ports.http.value;
  adminPort = config.processes.restate.ports.admin.value;
  nodePort = config.processes.restate.ports.node.value;

  # Wildcard addresses are fine to bind to, but not to connect to.
  connectHost =
    if
      builtins.elem cfg.host [
        "0.0.0.0"
        "::"
        "[::]"
      ]
    then
      "127.0.0.1"
    else
      cfg.host;

  ingressUrl = "http://${connectHost}:${toString ingressPort}";
  adminUrl = "http://${connectHost}:${toString adminPort}";
  nodeUrl = "http://${connectHost}:${toString nodePort}";

  # Read by the restate CLI.
  cliEnv = {
    RESTATE_ADMIN_URL = adminUrl;
    RESTATE_INGRESS_URL = ingressUrl;

    # The CLI environment selected in ~/.config/restate (such as a Restate Cloud one)
    # would otherwise apply its credentials to the managed server.
    RESTATE_ENVIRONMENT = "local";
  };

  generatedSettings = {
    node-name = cfg.nodeName;
    base-dir = cfg.stateDir;

    # Unix sockets are created under the data directory, and project paths
    # easily exceed the socket path length limit (104 bytes on macOS).
    listen-mode = "tcp";

    bind-address = "${cfg.host}:${toString nodePort}";
    advertised-address = "${nodeUrl}/";

    admin = {
      bind-address = "${cfg.host}:${toString adminPort}";
      advertised-address = "${adminUrl}/";
    };

    ingress = {
      bind-address = "${cfg.host}:${toString ingressPort}";
      advertised-address = "${ingressUrl}/";
    };

    disable-telemetry = true;

    # Production-oriented defaults, scaled down for a development machine.
    default-num-partitions = 4;
    rocksdb-total-memory-size = "512 MiB";
  };

  configFile = settingsFormat.generate "restate.toml" (
    lib.recursiveUpdate generatedSettings cfg.settings
  );

  # Listeners must stay on the ports devenv allocates, which client URLs and the ready probe use.
  # Advertised addresses only affect what Restate reports, so they can be overridden.
  conflictingSettings =
    let
      sections = {
        "" = cfg.settings;
        "admin." = cfg.settings.admin or { };
        "ingress." = cfg.settings.ingress or { };
      };

      conflicts =
        prefix: section:
        lib.optionals (lib.isAttrs section) (
          map (key: prefix + key) (
            builtins.filter (key: section ? ${key}) [
              "bind-address"
              "bind-ip"
              "bind-port"
              "use-random-ports"
            ]
          )
          ++ lib.optional ((section.listen-mode or null) == "unix") "${prefix}listen-mode"
        );
    in
    lib.concatLists (lib.mapAttrsToList conflicts sections);

  deploymentType = lib.types.submodule {
    options = {
      uri = lib.mkOption {
        type = lib.types.str;
        example = "http://127.0.0.1:9080";
        description = ''
          The endpoint of the deployment, as reachable from the Restate server.
        '';
      };

      after = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "devenv:processes:greeter" ];
        description = ''
          Processes or tasks to wait for before registering the deployment,
          such as the process serving it.
          Process dependencies wait for the process to be ready,
          so the process needs a ready probe or allocated ports.
        '';
      };

      force = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to replace an existing deployment at the same endpoint (`--force`),
          so that changed services are picked up.
          Without it, registering an endpoint that is already registered changes nothing.
        '';
      };

      http1 = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to use HTTP/1.1 for discovery (`--use-http1.1`),
          for endpoints that do not support HTTP/2, such as `wrangler dev`.
        '';
      };

      headers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          Authorization = "Bearer secret";
        };
        description = "Additional headers sent to the endpoint during discovery.";
      };
    };
  };

  registerCommand =
    deployment:
    lib.escapeShellArgs (
      [
        restate
        "--yes"
        "deployments"
        "register"
      ]
      ++ lib.optional deployment.force "--force"
      ++ lib.optional deployment.http1 "--use-http1.1"
      ++ lib.concatMap (name: [
        "--extra-header"
        "${name}=${deployment.headers.${name}}"
      ]) (lib.attrNames deployment.headers)
      ++ [ deployment.uri ]
    );
in
{
  options.services.restate = {
    enable = lib.mkEnableOption "Restate server for durable execution";

    package = lib.mkOption {
      type = lib.types.package;
      description = ''
        Which package of Restate to use. It must provide `restate-server` and `restate`.

        Restate is unfree, and nixpkgs builds it from source, which takes a long time.
        [nix-restate](https://github.com/sagikazarmark/nix-restate) provides
        `restate-bin`, built from the official release binaries.
      '';
      default = pkgs.restate;
      defaultText = lib.literalExpression "pkgs.restate";
      example = lib.literalExpression "inputs.nix-restate.packages.\${pkgs.stdenv.hostPlatform.system}.restate-bin";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        The host address the Restate server listens on.
        Wrap IPv6 addresses in brackets.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = ''
        The base port the Restate ingress listens on.
        The actual port is allocated by devenv and may differ;
        `RESTATE_INGRESS_URL` points to it.
      '';
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 9070;
      description = ''
        The base port the Restate admin API and web UI listen on.
        The actual port is allocated by devenv and may differ;
        `RESTATE_ADMIN_URL` points to it.
      '';
    };

    nodePort = lib.mkOption {
      type = lib.types.port;
      default = 5122;
      description = ''
        The base port Restate listens on for node-to-node communication.
        The actual port is allocated by devenv and may differ;
        `RESTATECTL_ADDRESS` points to it.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.devenv.state}/restate";
      defaultText = lib.literalExpression ''"''${config.devenv.state}/restate"'';
      description = ''
        The directory Restate stores its data in.
        Node data is kept in a subdirectory named after `nodeName`.
      '';
    };

    nodeName = lib.mkOption {
      type = lib.types.str;
      default = "devenv";
      description = ''
        The name of the Restate node.

        Restate defaults to the hostname, but the name must not change
        once the node stored data, so the module sets a fixed one.
        Changing it starts over with an empty node.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      example = {
        log-filter = "warn,restate=debug";
        default-journal-retention = "7d";
        worker.invoker.inactivity-timeout = "5m";
      };
      description = ''
        Restate server configuration, merged recursively over the generated configuration.
        See <https://docs.restate.dev/references/server-config> for available settings.

        The generated configuration listens on TCP only, disables telemetry,
        and provisions 4 partitions with 512 MiB of RocksDB memory.
        Partitions are only provisioned on the first start: remove `stateDir` to change them.

        Listeners use the ports devenv allocates, so `bind-address`, `bind-ip`, `bind-port`,
        `use-random-ports` and `listen-mode = "unix"` are rejected, globally and in `admin` and `ingress`:
        use `host`, `port`, `adminPort` and `nodePort` instead.
        Advertised addresses can be overridden, such as to point at the devenv proxy.
      '';
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        RUST_LOG = "info,restate=debug";
      };
      description = ''
        Additional environment variables for the Restate server process.
        `RESTATE_`-prefixed variables override configuration entries.
      '';
    };

    deployments = lib.mkOption {
      type = lib.types.attrsOf deploymentType;
      default = { };
      example = lib.literalExpression ''
        {
          greeter = {
            uri = "http://127.0.0.1:9080";
            after = [ "devenv:processes:greeter" ];
          };
        }
      '';
      description = ''
        Service deployments to register once Restate is ready,
        each with a `devenv:restate:register-<name>` task.

        Deployments are registered when Restate starts (with devenv 2.3.2 or newer;
        run `devenv up --mode all` with older versions).
        Register them again with `restate deployments register --force <uri>` after changing services.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = conflictingSettings == [ ];
        message = ''
          services.restate.settings must not set ${lib.concatStringsSep ", " conflictingSettings}:
          Restate listens on the ports devenv allocates. Use services.restate.host, port, adminPort and nodePort instead.
        '';
      }
    ];

    packages = [ cfg.package ];

    # Defaults, so that clients can be pointed elsewhere, such as at the devenv proxy.
    env = lib.mapAttrs (_: lib.mkDefault) (
      {
        # Read by restatectl.
        RESTATECTL_ADDRESS = nodeUrl;
      }
      // cliEnv
    );

    processes.restate = {
      exec = "exec ${restateServer} --no-logo --config-file ${configFile}";

      env = cfg.environmentVariables;

      ports.http.allocate = cfg.port;
      ports.admin.allocate = cfg.adminPort;
      ports.node.allocate = cfg.nodePort;

      # The admin API and the ingress start independently.
      ready.exec = ''
        ${curl} --fail --silent --output /dev/null ${lib.escapeShellArg "${adminUrl}/health"} \
          && ${curl} --fail --silent --output /dev/null ${lib.escapeShellArg "${ingressUrl}/restate/health"}
      '';
    };

    tasks = {
      "devenv:restate:setup" = {
        exec = "mkdir -p ${lib.escapeShellArg cfg.stateDir}";
        before = [ "devenv:processes:restate" ];
      };
    }
    // lib.mapAttrs' (
      name: deployment:
      lib.nameValuePair "devenv:restate:register-${name}" {
        description = "Register the ${name} Restate deployment";
        exec = registerCommand deployment;
        env = cliEnv;
        after = [ "devenv:processes:restate@ready" ] ++ deployment.after;
        # Without it, `devenv up` skips tasks that run after a process.
        wantedBy = lib.mkIf supportsWantedBy [ "devenv:processes:restate" ];
      }
    ) cfg.deployments;
  };
}
