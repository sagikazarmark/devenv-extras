{ config, pkgs, ... }:

let
  port = toString config.processes.openbao.ports.http.value;
in
{
  packages = [ pkgs.curl ];

  services.openbao.enable = true;

  assertions = [
    {
      assertion = config.services.openbao.storage.backend == "pebbledb";
      message = "services.openbao.storage.backend should default to pebbledb on OpenBao 2.7.";
    }
    {
      assertion = config.services.openbao.package == pkgs.openbao;
      message = "services.openbao.package should default to pkgs.openbao.";
    }
    {
      assertion = config.processes.openbao.ports.http.allocate == 8200;
      message = "The OpenBao API port should be allocated from 8200.";
    }
    {
      assertion = config.processes.openbao.ports.cluster.allocate == 8201;
      message = "The OpenBao cluster port should be allocated from 8201.";
    }
    {
      assertion = config.env.BAO_ADDR == "http://127.0.0.1:${port}";
      message = "BAO_ADDR should point clients at the allocated port.";
    }
    {
      assertion = config.env.BAO_TOKEN == "root";
      message = "BAO_TOKEN should default to the root token.";
    }
    {
      assertion = config.env.VAULT_ADDR == config.env.BAO_ADDR;
      message = "VAULT_ADDR should be exported by default.";
    }
    {
      assertion = config.env.VAULT_TOKEN == config.env.BAO_TOKEN;
      message = "VAULT_TOKEN should be exported by default.";
    }
  ];
}
