{ config, pkgs, ... }:

let
  port = toString config.processes.ollama.ports.http.value;
in
{
  packages = [ pkgs.curl ];

  services.ollama.enable = true;

  assertions = [
    {
      assertion = config.services.ollama.package == pkgs.ollama;
      message = "services.ollama.package should default to pkgs.ollama.";
    }
    {
      assertion = config.processes.ollama.ports.http.allocate == 11434;
      message = "The ollama HTTP port should be allocated from 11434.";
    }
    {
      assertion = config.env.OLLAMA_HOST == "127.0.0.1:${port}";
      message = "OLLAMA_HOST should point clients at the allocated port.";
    }
    {
      assertion = !(config.tasks ? "devenv:ollama:load-models");
      message = "The model loader task should only exist when models are declared.";
    }
  ];
}
