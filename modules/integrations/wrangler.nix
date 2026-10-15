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

  devModule =
    { name, ... }:
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

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "--env"
            "staging"
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

    processes = lib.mapAttrs' (
      name: worker:
      lib.nameValuePair "wrangler-${name}" {
        exec = "exec ${lib.getExe cfg.package} ${
          lib.escapeShellArgs (
            [
              "--cwd"
              "${config.devenv.root}/${worker.directory}"
            ]
            ++ lib.optionals (worker.config != null) [
              "--config"
              worker.config
            ]
            ++ [
              "dev"
              "--ip"
              worker.host
              "--port"
              (toString config.processes."wrangler-${name}".ports.http.value)
              "--inspector-port"
              (toString config.processes."wrangler-${name}".ports.inspector.value)
              # The process manager owns the terminal.
              "--show-interactive-dev-session=false"
            ]
            ++ worker.extraArgs
          )
        }";

        env = workerBuildEnv;

        ports.http.allocate = worker.port;
        ports.inspector.allocate = worker.inspectorPort;
      }
    ) cfg.dev;
  };
}
