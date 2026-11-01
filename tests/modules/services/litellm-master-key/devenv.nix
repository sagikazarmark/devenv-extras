{ config, pkgs, ... }:

{
  packages = [ pkgs.curl ];

  services.litellm = {
    enable = true;
    host = "0.0.0.0";
    environmentVariables.LITELLM_MASTER_KEY = "sk-devenv-extras-test";
    settings.model_list = [
      {
        model_name = "fake";
        litellm_params.model = "openai/fake";
      }
    ];
  };

  assertions = [
    {
      assertion =
        !config.services.litellm.permitWeakOrUnsetMasterKey
        && !(config.processes.litellm.env ? LITELLM_DANGEROUSLY_PERMIT_WEAK_OR_UNSET_MASTER_KEY);
      message = "LiteLLM should require a master key when it listens on a non-loopback address.";
    }
  ];
}
