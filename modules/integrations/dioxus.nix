{
  pkgs,
  config,
  lib,
  multiverse,
  ...
}:

let
  cfg = config.dioxus;

  versions = import ../lib/versions.nix {
    inherit
      pkgs
      lib
      config
      multiverse
      ;
  };

  inherit (versions) versioned versionDescription sourceDescription;

  lockedVersion = versions.lockedVersion cfg.cargoLock;
in
{
  options.dioxus = {
    enable = lib.mkEnableOption "the Dioxus CLI (dx)";

    cargoLock = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = versions.cargoLockDescription "dioxus and wasm-bindgen";
    };

    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = lockedVersion "dioxus";
      defaultText = lib.literalMD "the version of `dioxus` in Cargo.lock, or null";
      description = ''
        ${versionDescription "dioxus"}
        ${sourceDescription "dioxus-cli"}
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = versioned "dioxus-cli" cfg.version;
      defaultText = lib.literalMD "`dioxus-cli` at `version`, or `pkgs.dioxus-cli`";
      description = "The dioxus-cli package. Setting it overrides `version`.";
    };

    wasm-bindgen = {
      enable =
        lib.mkEnableOption "wasm-bindgen-cli, which dx and wasm-bindgen-test-runner need at the crate's exact version"
        // {
          default = true;
        };

      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = lockedVersion "wasm-bindgen";
        defaultText = lib.literalMD "the version of `wasm-bindgen` in Cargo.lock, or null";
        description = ''
          ${versionDescription "wasm-bindgen"}
          ${sourceDescription "wasm-bindgen-cli"}
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = versioned "wasm-bindgen-cli" cfg.wasm-bindgen.version;
        defaultText = lib.literalMD "`wasm-bindgen-cli` at `version`, or `pkgs.wasm-bindgen-cli`";
        description = "The wasm-bindgen-cli package. Setting it overrides `version`.";
      };
    };

    esbuild = {
      enable =
        lib.mkEnableOption "esbuild, which dx uses to minify JavaScript. The Nix build of dx does not download esbuild itself"
        // {
          default = true;
        };

      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The esbuild version to install.
          ${sourceDescription "esbuild"}
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = versioned "esbuild" cfg.esbuild.version;
        defaultText = lib.literalMD "`esbuild` at `version`, or `pkgs.esbuild`";
        description = "The esbuild package. Setting it overrides `version`.";
      };
    };

    wasm-opt = {
      enable =
        lib.mkEnableOption "wasm-opt (from binaryen), which dx uses to optimize WebAssembly. The Nix build of dx does not download wasm-opt itself"
        // {
          default = true;
        };

      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The binaryen version to install.
          ${sourceDescription "binaryen"}
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = versioned "binaryen" cfg.wasm-opt.version;
        defaultText = lib.literalMD "`binaryen` at `version`, or `pkgs.binaryen`";
        description = "The binaryen package that provides wasm-opt. Setting it overrides `version`.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      cfg.package
    ]
    ++ lib.optional cfg.wasm-bindgen.enable cfg.wasm-bindgen.package
    ++ lib.optional cfg.esbuild.enable cfg.esbuild.package
    ++ lib.optional cfg.wasm-opt.enable cfg.wasm-opt.package;
  };
}
