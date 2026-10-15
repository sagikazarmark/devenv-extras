{
  config,
  lib,
  pkgs,
  ...
}:

{
  dioxus.enable = true;

  assertions = [
    {
      assertion =
        config.dioxus.cargoLock == null
        && config.dioxus.version == null
        && config.dioxus.wasm-bindgen.version == null
        && config.dioxus.esbuild.version == null
        && config.dioxus.wasm-opt.version == null;
      message = "Without a Cargo.lock, dioxus versions should default to null.";
    }
    {
      assertion = config.dioxus.package == pkgs.dioxus-cli;
      message = "dioxus.package should default to pkgs.dioxus-cli.";
    }
    {
      assertion = config.dioxus.wasm-bindgen.package == pkgs.wasm-bindgen-cli;
      message = "dioxus.wasm-bindgen.package should default to pkgs.wasm-bindgen-cli.";
    }
    {
      assertion = config.dioxus.esbuild.package == pkgs.esbuild;
      message = "dioxus.esbuild.package should default to pkgs.esbuild.";
    }
    {
      assertion = config.dioxus.wasm-opt.package == pkgs.binaryen;
      message = "dioxus.wasm-opt.package should default to pkgs.binaryen.";
    }
    {
      assertion = builtins.all (p: builtins.elem p config.packages) [
        pkgs.dioxus-cli
        pkgs.wasm-bindgen-cli
        pkgs.esbuild
        pkgs.binaryen
      ];
      message = "dioxus.enable should install dx, wasm-bindgen-cli, esbuild and binaryen.";
    }
    {
      assertion = config.languages.rust.enable;
      message = "dioxus.enable should enable languages.rust.";
    }
    {
      assertion = lib.any (lib.hasInfix "wasm32-unknown-unknown") config.warnings;
      message = "dioxus should warn when the Rust toolchain does not have the wasm32-unknown-unknown target.";
    }
    {
      # Only evaluated, not built.
      assertion =
        lib.hasInfix "--fullstack" (config.dioxus.import ./. { fullstack = true; }).buildPhase
        && !lib.hasInfix "--fullstack" (config.dioxus.import ./. { }).buildPhase;
      message = "dioxus.import should pass --fullstack only for fullstack = true.";
    }
  ];
}
