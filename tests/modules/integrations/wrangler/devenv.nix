{ config, pkgs, ... }:

let
  api = config.processes.wrangler-api;
  app = config.processes.wrangler-app;
in
{
  packages = [ pkgs.curl ];

  languages.rust = {
    channel = "stable";
    targets = [ "wasm32-unknown-unknown" ];
  };

  worker-build.enable = true;

  # api defines the Counter Durable Object, and app uses it with script_name = "api".
  wrangler = {
    enable = true;
    dev = {
      api = { };
      app = { };
    };
  };

  env = {
    API_URL = "http://127.0.0.1:${toString api.ports.http.value}";
    APP_URL = "http://127.0.0.1:${toString app.ports.http.value}";
  };

  assertions = [
    {
      assertion =
        api.ports.http.allocate == 8787
        && app.ports.http.allocate == 8788
        && api.ports.inspector.allocate == 9229
        && app.ports.inspector.allocate == 9230;
      message = "Each worker should get its own default ports, counting up from Wrangler's.";
    }
    {
      assertion = config.env.WRANGLER_REGISTRY_PATH == "${config.devenv.state}/wrangler/registry";
      message = "The dev registry should default to the devenv state directory.";
    }
    {
      assertion =
        api.env.WASM_BINDGEN_BIN == "${config.worker-build.wasm-bindgen.package}/bin/wasm-bindgen";
      message = "worker-build should use wasm-bindgen from Nix in wrangler dev.";
    }
  ];
}
