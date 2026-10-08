{ config, pkgs, ... }:

{
  # This fixture has no nixpkgs-multiverse input: nothing here may resolve through it.
  worker-build = {
    enable = true;
    cargoLock = ./worker/Cargo.lock;
    package = pkgs.hello;
  };

  assertions = [
    {
      assertion = config.worker-build.version == "0.8.7";
      message = "worker-build.cargoLock should take precedence over Cargo.lock at the root.";
    }
    {
      assertion = config.worker-build.package == pkgs.hello && builtins.elem pkgs.hello config.packages;
      message = "worker-build.package should override worker-build.version.";
    }
  ];
}
