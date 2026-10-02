{ config, pkgs, ... }:

let
  port = toString config.processes.litellm.ports.http.value;
in
{
  packages = [ pkgs.curl ];

  services.litellm = {
    enable = true;
    settings.model_list = [
      {
        model_name = "fake";
        litellm_params.model = "openai/fake";
      }
    ];
  };

  assertions = [
    {
      assertion = config.services.litellm.package == pkgs.litellm;
      message = "services.litellm.package should default to pkgs.litellm.";
    }
    {
      assertion = config.processes.litellm.ports.http.allocate == 4000;
      message = "The litellm HTTP port should be allocated from 4000.";
    }
    {
      assertion = config.env.LITELLM_PROXY_URL == "http://127.0.0.1:${port}";
      message = "LITELLM_PROXY_URL should point clients at the allocated port.";
    }
    {
      assertion = config.env.LITELLM_PROXY_API_BASE == "http://127.0.0.1:${port}";
      message = "LITELLM_PROXY_API_BASE should point clients at the allocated port.";
    }
    {
      assertion = !config.services.litellm.ollama.enable;
      message = "The Ollama integration should be disabled when Ollama is disabled.";
    }
    {
      assertion = config.processes.litellm.after == [ ];
      message = "LiteLLM should not depend on Ollama when the integration is disabled.";
    }
  ];
}
