{ config, lib, ... }:

{
  languages.rust = {
    channel = "stable";
    targets = [ "wasm32-unknown-unknown" ];
  };

  languages.tailwindcss.enable = true;

  dioxus.enable = true;

  outputs.web = config.dioxus.import ./. {
    buildFeatures = [ "greeting" ];
  };

  # Building the shell builds the output, so .test.sh can check it.
  env.DIOXUS_OUTPUT = config.outputs.web;

  assertions = [
    {
      assertion = config.languages.rust.enable;
      message = "dioxus.enable should enable languages.rust.";
    }
    {
      assertion = !lib.any (lib.hasInfix "wasm32-unknown-unknown") config.warnings;
      message = "dioxus should not warn when the Rust toolchain has the wasm32-unknown-unknown target.";
    }
  ];
}
