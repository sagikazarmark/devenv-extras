{
  config,
  options,
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
  };

  assertions = [
    {
      # Only compare the documented default: evaluating pkgs.restate requires allowUnfree.
      assertion = options.services.restate.package.defaultText.text == "pkgs.restate";
      message = "Restate should default to the nixpkgs package.";
    }
    {
      assertion = config.processes.restate.ports.http.allocate == 8080;
      message = "The Restate ingress port should be allocated from 8080.";
    }
    {
      assertion = config.processes.restate.ports.admin.allocate == 9070;
      message = "The Restate admin port should be allocated from 9070.";
    }
    {
      assertion = config.processes.restate.ports.node.allocate == 5122;
      message = "The Restate node port should be allocated from 5122.";
    }
    {
      assertion = config.env.RESTATE_INGRESS_URL == "http://127.0.0.1:${ingressPort}";
      message = "RESTATE_INGRESS_URL should point to the allocated ingress port.";
    }
    {
      assertion = config.env.RESTATE_ADMIN_URL == "http://127.0.0.1:${adminPort}";
      message = "RESTATE_ADMIN_URL should point to the allocated admin port.";
    }
    {
      assertion = config.env.RESTATECTL_ADDRESS == "http://127.0.0.1:${nodePort}";
      message = "RESTATECTL_ADDRESS should point to the allocated node port.";
    }
    {
      assertion = config.env.RESTATE_ENVIRONMENT == "local";
      message = "The CLI should use the local environment.";
    }
    {
      assertion = config.processes.restate.ready.exec != null;
      message = "Restate should have a readiness probe.";
    }
    {
      assertion =
        !(builtins.any (pkgs.lib.hasPrefix "devenv:restate:register-") (builtins.attrNames config.tasks));
      message = "No registration tasks should exist without deployments.";
    }
  ];
}
