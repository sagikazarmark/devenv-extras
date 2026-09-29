{ config, pkgs, ... }:

let
  port = toString config.processes.ollama.ports.http.value;
in
{
  packages = [ pkgs.curl ];

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11500;
    modelsDir = "${config.devenv.state}/custom-models";
    environmentVariables.OLLAMA_KEEP_ALIVE = "1m";
  };

  assertions = [
    {
      assertion = config.processes.ollama.ports.http.allocate == 11500;
      message = "The ollama HTTP port should be allocated from the configured port.";
    }
    {
      assertion = config.processes.ollama.env.OLLAMA_HOST == "0.0.0.0:${port}";
      message = "The ollama server should bind to the configured host.";
    }
    {
      assertion = config.env.OLLAMA_HOST == "127.0.0.1:${port}";
      message = "Clients should connect to loopback when the server binds a wildcard address.";
    }
    {
      assertion = config.env.OLLAMA_BASE_URL == "http://127.0.0.1:${port}/v1";
      message = "OLLAMA_BASE_URL should connect to loopback when the server binds a wildcard address.";
    }
    {
      assertion = config.processes.ollama.env.OLLAMA_KEEP_ALIVE == "1m";
      message = "Extra environment variables should be passed to the server process.";
    }
  ];
}
