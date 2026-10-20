{
  config,
  pkgs,
  inputs,
  ...
}:

let
  ingressPort = toString config.processes.restate.ports.http.value;
  adminPort = toString config.processes.restate.ports.admin.value;
  nodePort = toString config.processes.restate.ports.node.value;
in
{
  packages = [
    pkgs.curl
    pkgs.jq
  ];

  services.restate = {
    enable = true;
    package = inputs.nix-restate.packages.${pkgs.stdenv.hostPlatform.system}.restate-bin;
    host = "0.0.0.0";
    port = 8180;
    adminPort = 9170;
    nodePort = 5222;
    stateDir = "${config.devenv.state}/custom-restate";
    nodeName = "test-node";
    settings = {
      cluster-name = "devenv-test";
      # Overrides the generated default.
      default-num-partitions = 2;
      # Merged into the generated section, which keeps its bind address.
      admin.disable-web-ui = true;
    };
    environmentVariables.RESTATE_LOG_FILTER = "warn,restate=debug";
  };

  assertions = [
    {
      assertion = config.processes.restate.ports.http.allocate == 8180;
      message = "The Restate ingress port should be allocated from the configured port.";
    }
    {
      assertion = config.processes.restate.ports.admin.allocate == 9170;
      message = "The Restate admin port should be allocated from the configured port.";
    }
    {
      assertion = config.processes.restate.ports.node.allocate == 5222;
      message = "The Restate node port should be allocated from the configured port.";
    }
    {
      assertion =
        config.env.RESTATE_INGRESS_URL == "http://127.0.0.1:${ingressPort}"
        && config.env.RESTATE_ADMIN_URL == "http://127.0.0.1:${adminPort}"
        && config.env.RESTATECTL_ADDRESS == "http://127.0.0.1:${nodePort}";
      message = "Clients should connect to loopback when the server binds a wildcard address.";
    }
    {
      assertion = config.processes.restate.env.RESTATE_LOG_FILTER == "warn,restate=debug";
      message = "Extra environment variables should be passed to the server process.";
    }
  ];
}
