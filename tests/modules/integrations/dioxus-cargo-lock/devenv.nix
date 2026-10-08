{ config, pkgs, ... }:

{
  dioxus = {
    enable = true;
    esbuild.version = "0.25.5";
    wasm-opt.version = "131";
  };

  assertions = [
    {
      assertion = config.dioxus.version == "0.7.9";
      message = "dioxus.version should default to the dioxus version in Cargo.lock.";
    }
    {
      assertion = config.dioxus.wasm-bindgen.version == "0.2.100";
      message = "dioxus.wasm-bindgen.version should default to the wasm-bindgen version in Cargo.lock.";
    }
    {
      # nixpkgs does not have dx 0.7.9, so it comes from nixpkgs-multiverse.
      assertion = config.dioxus.package.version == "0.7.9";
      message = "dioxus.package should be dioxus-cli at dioxus.version.";
    }
    {
      assertion = config.dioxus.wasm-bindgen.package.version == "0.2.100";
      message = "dioxus.wasm-bindgen.package should be wasm-bindgen-cli at dioxus.wasm-bindgen.version.";
    }
    {
      assertion =
        pkgs ? wasm-bindgen-cli_0_2_100 -> config.dioxus.wasm-bindgen.package == pkgs.wasm-bindgen-cli_0_2_100;
      message = "dioxus.wasm-bindgen.package should prefer a versioned nixpkgs attribute over nixpkgs-multiverse.";
    }
    {
      assertion = config.dioxus.esbuild.package.version == "0.25.5";
      message = "dioxus.esbuild.package should be esbuild at dioxus.esbuild.version.";
    }
    {
      assertion = config.dioxus.wasm-opt.package.version == "131";
      message = "dioxus.wasm-opt.package should be binaryen at dioxus.wasm-opt.version.";
    }
  ];
}
