{ config, pkgs, ... }:

{
  packages = [ pkgs.curl ];

  languages.rust = {
    channel = "stable";
    targets = [ "wasm32-unknown-unknown" ];
  };

  dioxus = {
    enable = true;
    serve.enable = true;
  };

  env.DIOXUS_SERVE_URL = "http://127.0.0.1:${toString config.processes.dioxus.ports.http.value}";

  assertions = [
    {
      assertion = config.processes.dioxus.ports.http.allocate == 8080;
      message = "The dx serve port should be allocated from 8080.";
    }
  ];
}
