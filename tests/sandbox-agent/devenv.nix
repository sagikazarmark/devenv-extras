{ config, pkgs, ... }:

{
  packages = [
    pkgs.curl
    pkgs.sandbox-agent
  ];

  services.sandbox-agent.enable = true;

  assertions = [
    {
      assertion = pkgs ? sandbox-agent;
      message = "The sandbox-agent overlay did not add pkgs.sandbox-agent.";
    }
    {
      assertion = config.services.sandbox-agent.package == pkgs.sandbox-agent;
      message = "services.sandbox-agent.package should default to pkgs.sandbox-agent.";
    }
    {
      assertion = config.processes.sandbox-agent.ports.http.value == 2468;
      message = "The sandbox-agent HTTP port should be 2468 in the fixture.";
    }
  ];
}
