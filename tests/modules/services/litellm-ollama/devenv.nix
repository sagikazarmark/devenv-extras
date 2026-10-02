{ config, pkgs, ... }:

let
  ollamaPort = toString config.processes.ollama.ports.http.value;
in
{
  packages = [ pkgs.curl ];

  services.ollama.enable = true;

  services.litellm = {
    enable = true;
    ollama.models = [ "gemma3" ];
  };

  assertions = [
    {
      assertion = config.services.litellm.ollama.enable;
      message = "The Ollama integration should be enabled when Ollama is enabled.";
    }
    {
      assertion = config.processes.litellm.after == [ "devenv:processes:ollama" ];
      message = "LiteLLM should start after Ollama is ready.";
    }
    {
      assertion =
        config.services.litellm.settings.model_list == [
          {
            model_name = "ollama/*";
            litellm_params = {
              model = "ollama_chat/*";
              api_base = "http://127.0.0.1:${ollamaPort}";
            };
          }
          {
            model_name = "ollama/gemma3";
            litellm_params = {
              model = "ollama_chat/gemma3";
              api_base = "http://127.0.0.1:${ollamaPort}";
            };
          }
        ];
      message = "Ollama models should be routed to the managed Ollama server.";
    }
  ];
}
