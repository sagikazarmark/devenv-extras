{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.litellm;

  settingsFormat = pkgs.formats.yaml { };

  port = config.processes.litellm.ports.http.value;

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

  baseUrl = "http://${connectHost}:${toString port}";

  ollamaModels =
    let
      litellmParams = model: {
        model = "ollama_chat/${model}";
        api_base = "http://${config.env.OLLAMA_HOST}";
      };
    in
    [
      {
        model_name = "${cfg.ollama.prefix}*";
        litellm_params = litellmParams "*";
      }
    ]
    ++ map (model: {
      model_name = "${cfg.ollama.prefix}${model}";
      litellm_params = litellmParams model;
    }) cfg.ollama.models;

  configFile = settingsFormat.generate "litellm-config.yaml" cfg.settings;
in
{
  options.services.litellm = {
    enable = lib.mkEnableOption "LiteLLM proxy server";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which package of LiteLLM to use.";
      default = pkgs.litellm;
      defaultText = lib.literalExpression "pkgs.litellm";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "The host address the LiteLLM HTTP server listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = ''
        The base port the LiteLLM HTTP server listens on.
        The actual port is allocated by devenv and may differ;
        `LITELLM_PROXY_URL` and `LITELLM_PROXY_API_BASE` point to it.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.devenv.state}/litellm";
      defaultText = lib.literalExpression ''"''${config.devenv.state}/litellm"'';
      description = "The directory LiteLLM stores runtime files (such as the admin UI) in.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;

        options = {
          model_list = lib.mkOption {
            type = lib.types.listOf settingsFormat.type;
            default = [ ];
            description = "Models served by the proxy, with model-specific configuration.";
          };

          router_settings = lib.mkOption {
            type = settingsFormat.type;
            default = { };
            description = "LiteLLM router settings.";
          };

          litellm_settings = lib.mkOption {
            type = settingsFormat.type;
            default = { };
            description = "LiteLLM module settings.";
          };

          general_settings = lib.mkOption {
            type = settingsFormat.type;
            default = { };
            description = "LiteLLM server settings.";
          };

          environment_variables = lib.mkOption {
            type = settingsFormat.type;
            default = { };
            description = "Environment variables LiteLLM sets for itself on startup.";
          };
        };
      };
      default = { };
      example = lib.literalExpression ''
        {
          model_list = [
            {
              model_name = "claude-sonnet";
              litellm_params = {
                model = "anthropic/claude-sonnet-4-5";
                api_key = "os.environ/ANTHROPIC_API_KEY";
              };
            }
          ];
        }
      '';
      description = ''
        LiteLLM proxy configuration, rendered to the YAML file passed to `--config`.
        See <https://docs.litellm.ai/docs/proxy/configs> for available settings.
      '';
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        LITELLM_LOG = "DEBUG";
      };
      description = ''
        Additional environment variables for the LiteLLM server process.
        Telemetry is disabled by default; these variables take precedence.
      '';
    };

    ollama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.services.ollama.enable;
        defaultText = lib.literalExpression "config.services.ollama.enable";
        description = ''
          Whether to route models to the Ollama server managed by `services.ollama`.

          Requests for `<prefix><model>` (such as `ollama/gemma3`) are forwarded
          to the Ollama server, and LiteLLM starts after Ollama is ready.
        '';
      };

      prefix = lib.mkOption {
        type = lib.types.str;
        default = "ollama/";
        description = "The prefix of model names routed to Ollama.";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = config.services.ollama.loadModels;
        defaultText = lib.literalExpression "config.services.ollama.loadModels";
        description = ''
          Ollama models listed explicitly in the proxy's model list,
          so that clients discover them through `/v1/models`.
          Other models are still routed to Ollama through a wildcard entry.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        packages = [ cfg.package ];

        env = {
          # Read by the litellm-proxy CLI.
          LITELLM_PROXY_URL = baseUrl;

          # Read by the LiteLLM SDK for `litellm_proxy/` models.
          LITELLM_PROXY_API_BASE = baseUrl;
        };

        processes.litellm = {
          exec = "exec ${lib.getExe cfg.package} --host ${lib.escapeShellArg cfg.host} --port ${toString port} --config ${configFile}";

          env = {
            SCARF_NO_ANALYTICS = "True";
            DO_NOT_TRACK = "True";
            ANONYMIZED_TELEMETRY = "False";
          }
          // cfg.environmentVariables
          // {
            # LiteLLM rewrites its packaged UI files on startup.
            # The package lives in the read-only Nix store, so point it at a writable path.
            LITELLM_NON_ROOT = "true";
            LITELLM_UI_PATH = "${cfg.stateDir}/ui";
          };

          ports.http.allocate = cfg.port;

          ready.http.get = {
            host = connectHost;
            inherit port;
            path = "/health/liveliness";
          };
        };

        tasks."devenv:litellm:setup" = {
          # LiteLLM copies UI assets from the Nix store with read-only permissions;
          # make them writable again so it can update them on the next start.
          exec = ''
            mkdir -p ${lib.escapeShellArg "${cfg.stateDir}/ui"}
            chmod -R u+rwX ${lib.escapeShellArg "${cfg.stateDir}/ui"}
          '';
          before = [ "devenv:processes:litellm" ];
        };
      }

      (lib.mkIf cfg.ollama.enable {
        assertions = [
          {
            assertion = config.services.ollama.enable;
            message = "services.litellm.ollama.enable requires services.ollama.enable.";
          }
        ];

        services.litellm.settings.model_list = lib.mkIf config.services.ollama.enable ollamaModels;

        processes.litellm.after = [ "devenv:processes:ollama" ];
      })
    ]
  );
}
