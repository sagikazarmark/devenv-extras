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
      # The module adds zstd to worker-build 0.8.7 when nixpkgs does not have it.
      assertion = config.worker-build.package.name == pkgs.worker-build.name;
      message = "worker-build.package should default to pkgs.worker-build.";
    }
    {
      assertion = builtins.elem config.worker-build.package config.packages;
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
    {
      # Only evaluated, not built.
      assertion =
        let
          member = config.worker-build.import ./workspace { buildAndTestSubdir = "member"; };
        in
        member.pname == "member" && member.version == "1.2.3";
      message = "worker-build.import should read a version inherited from the workspace.";
    }
  ];
}
