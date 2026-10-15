{
  config,
  lib,
  pkgs,
  ...
}:

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
    {
      assertion = config.languages.rust.enable;
      message = "worker-build.enable should enable languages.rust.";
    }
    {
      assertion = lib.any (lib.hasInfix "wasm32-unknown-unknown") config.warnings;
      message = "worker-build should warn when the Rust toolchain does not have the wasm32-unknown-unknown target.";
    }
  ];
}
