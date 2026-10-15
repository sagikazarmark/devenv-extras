{
  pkgs,
  config,
  lib,
  multiverse,
  ...
}:

let
  cfg = config.worker-build;

  versions = import ../lib/versions.nix {
    inherit
      pkgs
      lib
      config
      multiverse
      ;
  };

  rust = import ../lib/rust.nix { inherit pkgs lib config; };
in
{
  options.worker-build = {
    enable = lib.mkEnableOption "worker-build, which builds Rust Cloudflare Workers";

    cargoLock = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = versions.cargoLockDescription "worker and wasm-bindgen";
    };

    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = versions.lockedVersion cfg.cargoLock "worker";
      defaultText = lib.literalMD "the version of `worker` in Cargo.lock, or null";
      description = ''
        ${versions.versionDescription "worker"}
        ${versions.sourceDescription "worker-build"}
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = versions.versioned "worker-build" cfg.version;
      defaultText = lib.literalMD "`worker-build` at `version`, or `pkgs.worker-build`";
      description = "The worker-build package. Setting it overrides `version`.";
    };

    wasm-bindgen = {
      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = versions.lockedVersion cfg.cargoLock "wasm-bindgen";
        defaultText = lib.literalMD "the version of `wasm-bindgen` in Cargo.lock, or null";
        description = ''
          The wasm-bindgen-cli version that `import` builds with.
          ${versions.versionDescription "wasm-bindgen"}
          ${versions.sourceDescription "wasm-bindgen-cli"}
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = versions.versioned "wasm-bindgen-cli" cfg.wasm-bindgen.version;
        defaultText = lib.literalMD "`wasm-bindgen-cli` at `version`, or `pkgs.wasm-bindgen-cli`";
        description = "The wasm-bindgen-cli package that `import` builds with. Setting it overrides `version`.";
      };
    };

    esbuild.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.esbuild;
      defaultText = lib.literalExpression "pkgs.esbuild";
      description = "The esbuild package that `import` builds with.";
    };

    wasm-opt.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.binaryen;
      defaultText = lib.literalExpression "pkgs.binaryen";
      description = "The binaryen package that provides wasm-opt for `import` builds.";
    };

    import = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      readOnly = true;
      default =
        path:
        {
          release ? true,
          workerBuildFlags ? [ ],
          ...
        }@args:
        let
          cargoFlags = rust.featureFlags args;
        in
        rust.importCargo
          {
            name = "worker-build.import";
            nativeBuildInputs = [ cfg.package ];

            # worker-build downloads these unless they are set, which fails in the Nix sandbox.
            env = {
              WASM_BINDGEN_BIN = lib.getExe' cfg.wasm-bindgen.package "wasm-bindgen";
              ESBUILD_BIN = lib.getExe cfg.esbuild.package;
              WASM_OPT_BIN = lib.getExe' cfg.wasm-opt.package "wasm-opt";
            };

            buildCommand = "worker-build ${
              lib.escapeShellArgs (
                [ (if release then "--release" else "--dev") ]
                ++ workerBuildFlags
                ++ lib.optionals (cargoFlags != [ ]) ([ "--" ] ++ cargoFlags)
              )
            }";
            installCommand = ''cp -R build "$out"'';
          }
          path
          (
            builtins.removeAttrs args [
              "release"
              "workerBuildFlags"
            ]
          );
      defaultText = lib.literalMD "a function that builds a worker with worker-build";
      description = ''
        Build a Cargo project with worker-build, for example to use it in `outputs`.

        It takes the path to the project (the directory with Cargo.lock) and an attribute set of
        arguments, and returns a package with the contents of worker-build's `build` directory.
        Dependencies are vendored from Cargo.lock, so the build runs offline, and worker-build uses
        the `wasm-bindgen`, `esbuild` and `wasm-opt` packages instead of downloading them.

        The arguments are:

        - `release`: build with `--release` (the default) or `--dev`.
        - `buildFeatures` and `buildNoDefaultFeatures`: the cargo features to build with.
        - `workerBuildFlags`: more flags for worker-build, such as `[ "--no-opt" ]`.
        - `rustPlatform`: the `rustPlatform` to build with, instead of one with the devenv Rust toolchain.

        Other arguments, such as `buildAndTestSubdir` for a crate in a workspace subdirectory or
        `buildInputs`, are passed to `rustPlatform.buildRustPackage`.

        The devenv Rust toolchain needs the wasm32-unknown-unknown target:

        ```nix
        languages.rust = {
          enable = true;
          channel = "stable";
          targets = [ "wasm32-unknown-unknown" ];
        };

        outputs.worker = config.worker-build.import ./. { };
        ```
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package ];

    languages.rust.enable = lib.mkDefault true;

    warnings = rust.wasmTargetWarnings "worker-build";
  };
}
