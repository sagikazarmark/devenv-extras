{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.sandbox-agent;
in
{
  options.services.sandbox-agent = {
    enable = lib.mkEnableOption "Sandbox Agent";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which package of sandbox-agent to use";
      default = pkgs.sandbox-agent;
      defaultText = lib.literalExpression "pkgs.sandbox-agent";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host to bind";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 2468;
      description = "Port to bind";
    };

    token = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Token to use for authentication";
      example = "foo";
    };

    cors = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "CORS";

          allowedOrigins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of allowed origins for CORS";
          };

          allowedMethods = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of allowed methods for CORS";
          };

          allowedHeaders = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of allowed headers for CORS";
          };

          allowCredentials = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to allow credentials for CORS";
          };
        };
      };
      default = { };
      description = "CORS configuration for Sandbox Agent";
    };
  };

  config = lib.mkIf cfg.enable {
    processes.sandbox-agent = {
      exec =
        let
          args =
            [
              "--host"
              cfg.host
              "--port"
              (toString config.processes.sandbox-agent.ports.http.value)
              "--no-telemetry"
            ]
            ++ (
              if cfg.token != null then
                [
                  "--token"
                  cfg.token
                ]
              else
                [ "--no-token" ]
            )
            ++ lib.optionals cfg.cors.enable (
              lib.concatMap (origin: [
                "--cors-allow-origin"
                origin
              ]) cfg.cors.allowedOrigins
              ++ lib.concatMap (method: [
                "--cors-allow-method"
                method
              ]) cfg.cors.allowedMethods
              ++ lib.concatMap (header: [
                "--cors-allow-header"
                header
              ]) cfg.cors.allowedHeaders
              ++ lib.optional cfg.cors.allowCredentials "--cors-allow-credentials"
            );
        in
        "${cfg.package}/bin/sandbox-agent server ${lib.escapeShellArgs args}";

      env = {
        SANDBOX_AGENT_LOG_STDOUT = "1";
      };

      ports = {
        http.allocate = cfg.port;
      };

      ready.http.get = {
        port = config.processes.sandbox-agent.ports.http.value;
        path = "/";
      };
    };
  };
}
