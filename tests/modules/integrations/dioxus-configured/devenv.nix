{ config, pkgs, ... }:

{
  # This fixture has no nixpkgs-multiverse input: nothing here may resolve through it.
  dioxus = {
    enable = true;
    cargoLock = ./app/Cargo.lock;
    package = pkgs.hello;
    wasm-bindgen.version = pkgs.wasm-bindgen-cli.version;
    esbuild.version = pkgs.esbuild.version;
    wasm-opt.enable = false;
  };

  assertions = [
    {
      assertion = config.dioxus.version == "0.7.9";
      message = "dioxus.cargoLock should take precedence over Cargo.lock at the root.";
    }
    {
      assertion = config.dioxus.package == pkgs.hello && builtins.elem pkgs.hello config.packages;
      message = "dioxus.package should override dioxus.version.";
    }
    {
      assertion = config.dioxus.wasm-bindgen.package == pkgs.wasm-bindgen-cli;
      message = "dioxus.wasm-bindgen.version should override Cargo.lock and resolve to nixpkgs when it matches.";
    }
    {
      assertion = builtins.elem pkgs.wasm-bindgen-cli config.packages;
      message = "dioxus.wasm-bindgen.enable should install wasm-bindgen-cli by default.";
    }
    {
      assertion = config.dioxus.esbuild.package == pkgs.esbuild && builtins.elem pkgs.esbuild config.packages;
      message = "dioxus.esbuild.version should resolve to nixpkgs when it matches.";
    }
    {
      assertion = !(builtins.elem config.dioxus.wasm-opt.package config.packages);
      message = "dioxus.wasm-opt.enable = false should not install binaryen.";
    }
  ];
}
