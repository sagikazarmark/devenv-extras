{ config, pkgs, ... }:

let
  port = toString config.processes.openbao.ports.http.value;
in
{
  packages = [ pkgs.curl ];

  services.openbao = {
    enable = true;
    host = "0.0.0.0";
    port = 8300;
    clusterPort = 8301;
    token = "devenv-test";
    ui.enable = false;
    kv.path = "kv";
    storage.backend = "raft";
    exportVaultEnv = false;
    settings.log_level = "debug";
    environmentVariables.TEST_PASSWORD = "hunter2";
    initialize = [
      {
        name = "userpass";
        requests = [
          {
            name = "enable-userpass";
            operation = "update";
            path = "sys/auth/userpass";
            data.type = "userpass";
          }
          {
            name = "add-alice";
            operation = "update";
            path = "auth/userpass/users/alice";
            data = {
              password = {
                eval_source = "env";
                eval_type = "string";
                env_var = "TEST_PASSWORD";
                require_present = true;
              };
              token_policies = [ "default" ];
            };
          }
        ];
      }
    ];
  };

  assertions = [
    {
      assertion = config.processes.openbao.ports.http.allocate == 8300;
      message = "The OpenBao API port should be allocated from the configured port.";
    }
    {
      assertion = config.processes.openbao.ports.cluster.allocate == 8301;
      message = "The OpenBao cluster port should be allocated from the configured port.";
    }
    {
      assertion = config.env.BAO_ADDR == "http://127.0.0.1:${port}";
      message = "Clients should connect to loopback when the server binds a wildcard address.";
    }
    {
      assertion = config.env.BAO_TOKEN == "devenv-test";
      message = "BAO_TOKEN should be the configured token.";
    }
    {
      assertion = !(config.env ? VAULT_ADDR) && !(config.env ? VAULT_TOKEN);
      message = "Vault variables should not be exported when exportVaultEnv is disabled.";
    }
    {
      assertion = config.processes.openbao.env.TEST_PASSWORD == "hunter2";
      message = "Extra environment variables should be passed to the server process.";
    }
  ];
}
