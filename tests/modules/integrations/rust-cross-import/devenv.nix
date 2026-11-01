{
  config,
  lib,
  pkgs,
  ...
}:

let
  host = pkgs.stdenv.buildPlatform.rust.rustcTarget;

  import = config.rust-cross.import ./.;

  fails = drv: !(builtins.tryEval drv.drvPath).success;
in
{
  languages.rust = {
    channel = "stable";
    targets = [
      "x86_64-unknown-linux-musl"
      "aarch64-unknown-linux-gnu"
      "x86_64-apple-darwin"
    ];
  };

  rust-cross.enable = true;

  packages = [ pkgs.file ];

  outputs = {
    host = import {
      target = host;
      buildFeatures = [ "greeting" ];
    };
    x86_64-linux-musl = import { target = "x86_64-unknown-linux-musl"; };
    aarch64-linux-gnu = import { target = "aarch64-unknown-linux-gnu.2.17"; };
    x86_64-darwin = import {
      target = "x86_64-apple-darwin";
      cargoBuildFlags = [ "--lib" ];
    };
  };

  # Building the shell builds the outputs, so .test.sh can check them.
  env = {
    RUST_CROSS_HOST = config.outputs.host;
    RUST_CROSS_X86_64_LINUX_MUSL = config.outputs.x86_64-linux-musl;
    RUST_CROSS_AARCH64_LINUX_GNU = config.outputs.aarch64-linux-gnu;
    RUST_CROSS_X86_64_DARWIN = config.outputs.x86_64-darwin;
  };

  assertions = [
    {
      assertion = config.outputs.aarch64-linux-gnu.pname == "hello-cross-aarch64-unknown-linux-gnu";
      message = "rust-cross.import should name the package after the crate and the target triple.";
    }
    {
      assertion = fails (import {
        target = "riscv64gc-unknown-linux-gnu";
      });
      message = "rust-cross.import should fail for a target the Rust toolchain does not have.";
    }
    {
      assertion = fails (import {
        target = "universal2-apple-darwin";
      });
      message = "rust-cross.import should reject universal2-apple-darwin.";
    }
    {
      assertion = lib.hasInfix "cargo build" config.outputs.host.buildPhase;
      message = "rust-cross.import should build the host target with cargo build.";
    }
    {
      assertion = lib.hasInfix "cargo zigbuild" config.outputs.x86_64-linux-musl.buildPhase;
      message = "rust-cross.import should cross-compile with cargo zigbuild.";
    }
  ];
}
