{ config, pkgs, ... }:

{
  packages = [ pkgs.curl ];

  languages.rust = {
    channel = "stable";
    targets = [ "wasm32-unknown-unknown" ];
  };

  dioxus.enable = true;

  # dx builds the server as well, because the fullstack feature of dioxus is enabled.
  outputs.app = config.dioxus.import ./. { };

  # Building the shell builds the output, so .test.sh can check it.
  env.DIOXUS_OUTPUT = config.outputs.app;
}
