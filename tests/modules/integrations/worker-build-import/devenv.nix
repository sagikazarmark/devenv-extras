{ config, lib, ... }:

{
  languages.rust = {
    channel = "stable";
    targets = [ "wasm32-unknown-unknown" ];
  };

  worker-build.enable = true;

  outputs.worker = config.worker-build.import ./. {
    buildFeatures = [ "greeting" ];
  };

  # Building the shell builds the output, so .test.sh can check it.
  env.WORKER_BUILD_OUTPUT = config.outputs.worker;

  assertions = [
    {
      assertion = config.languages.rust.enable;
      message = "worker-build.enable should enable languages.rust.";
    }
    {
      assertion = !lib.any (lib.hasInfix "wasm32-unknown-unknown") config.warnings;
      message = "worker-build should not warn when the Rust toolchain has the wasm32-unknown-unknown target.";
    }
    {
      assertion = config.worker-build.wasm-bindgen.version == "0.2.129";
      message = "worker-build.wasm-bindgen.version should default to the wasm-bindgen version in Cargo.lock.";
    }
  ];
}
