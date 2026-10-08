{ config, pkgs, ... }:

{
  worker-build.enable = true;

  assertions = [
    {
      assertion = config.worker-build.cargoLock == null && config.worker-build.version == null;
      message = "Without a Cargo.lock, worker-build.version should default to null.";
    }
    {
      assertion = config.worker-build.package == pkgs.worker-build;
      message = "worker-build.package should default to pkgs.worker-build.";
    }
    {
      assertion = builtins.elem pkgs.worker-build config.packages;
      message = "worker-build.enable should install worker-build.";
    }
  ];
}
