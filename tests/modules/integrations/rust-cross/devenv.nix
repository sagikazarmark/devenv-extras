{
  config,
  lib,
  pkgs,
  ...
}:

{
  languages.rust = {
    channel = "stable";
    targets = [ "aarch64-unknown-linux-musl" ];
  };

  rust-cross.enable = true;

  packages = [ pkgs.file ];

  assertions = [
    {
      assertion = builtins.elem config.rust-cross.package config.packages;
      message = "rust-cross.enable should install cargo-zigbuild.";
    }
    {
      assertion = lib.versionAtLeast config.rust-cross.package.version "0.24.0";
      message = "rust-cross.package should default to cargo-zigbuild 0.24.0 or later.";
    }
    {
      assertion = config.languages.rust.enable;
      message = "rust-cross.enable should enable languages.rust.";
    }
    {
      assertion = config.languages.zig.enable && !config.languages.zig.lsp.enable;
      message = "rust-cross.enable should enable languages.zig without the language server.";
    }
  ];
}
