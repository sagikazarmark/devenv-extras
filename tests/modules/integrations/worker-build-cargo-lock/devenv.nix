{ config, ... }:

{
  worker-build.enable = true;

  assertions = [
    {
      assertion = config.worker-build.version == "0.8.7";
      message = "worker-build.version should default to the worker version in Cargo.lock.";
    }
    {
      # worker-build 0.8.7 comes from nixpkgs if it has it, otherwise from nixpkgs-multiverse.
      assertion = config.worker-build.package.version == "0.8.7";
      message = "worker-build.package should be worker-build at worker-build.version.";
    }
  ];
}
