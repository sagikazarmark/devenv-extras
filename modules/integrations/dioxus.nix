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

  rust = import ../lib/rust.nix { inherit pkgs lib config; };
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

    serve = {
      enable = lib.mkEnableOption "a `dioxus` process that runs `dx serve`, which rebuilds and hot-reloads the app";

      directory = lib.mkOption {
        type = lib.types.str;
        default = ".";
        example = "app";
        description = "The directory of the crate to serve, relative to the project root.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = "The address the dev server listens on.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = ''
          The base port the dev server listens on.
          The actual port is allocated by devenv and may differ;
          `config.processes.dioxus.ports.http.value` has it.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "--platform"
          "web"
          "--hot-patch"
        ];
        description = "More arguments for `dx serve`.";
      };
    };

    import = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      readOnly = true;
      default =
        path:
        {
          platform ? "web",
          fullstack ? false,
          release ? true,
          dxFlags ? [ ],
          ...
        }@args:
        rust.importCargo
          {
            name = "dioxus.import";

            # The Nix build of dx finds these on PATH instead of downloading them.
            nativeBuildInputs = [
              cfg.package
              cfg.wasm-bindgen.package
              cfg.esbuild.package
              cfg.wasm-opt.package
            ]
            # dx runs Tailwind CSS when the app uses it.
            ++ lib.optional config.languages.tailwindcss.enable config.languages.tailwindcss.package;

            buildCommand = "dx bundle ${
              lib.escapeShellArgs (
                [
                  "--platform"
                  platform
                ]
                ++ lib.optional release "--release"
                # dx has no way to turn the server off: --fullstack=false is the same as leaving it out.
                ++ lib.optional fullstack "--fullstack"
                ++ rust.featureFlags args
                ++ dxFlags
              )
            } --out-dir dist";
            installCommand = ''cp -R dist "$out"'';
          }
          path
          (
            builtins.removeAttrs args [
              "platform"
              "fullstack"
              "release"
              "dxFlags"
            ]
          );
      defaultText = lib.literalMD "a function that builds an app with `dx bundle`";
      description = ''
        Build a Cargo project with `dx bundle`, for example to use it in `outputs`.

        It takes the path to the project (the directory with Cargo.lock) and an attribute set of
        arguments, and returns a package with the bundle: `public` with the web app, and the server
        executable for fullstack apps. Dependencies are vendored from Cargo.lock, so the build runs
        offline, and dx uses the `wasm-bindgen`, `esbuild` and `wasm-opt` packages, whether or not
        they are enabled in the shell, and the `languages.tailwindcss` package if it is enabled.
        dx reads Dioxus.toml as usual, except for `out_dir`.

        The arguments are:

        - `platform`: the platform to bundle for, `"web"` by default. Platforms other than web need
          packaging tools that may not work in the Nix sandbox.
        - `fullstack`: build the server as well, even when the `fullstack` feature of `dioxus` is not
          enabled. dx always builds it when that feature is enabled, either on the `dioxus` dependency
          or through a crate feature in `buildFeatures`, so leave it out of those for a client-only bundle.
        - `release`: build with `--release` (the default).
        - `buildFeatures` and `buildNoDefaultFeatures`: the cargo features to build with.
        - `dxFlags`: more flags for `dx bundle`, such as `[ "--base-path" "app" ]`.
        - `rustPlatform`: the `rustPlatform` to build with, instead of one with the devenv Rust toolchain.

        Other arguments, such as `buildAndTestSubdir` for a crate in a workspace subdirectory or
        `buildInputs` for the server's system libraries, are passed to `rustPlatform.buildRustPackage`.

        The devenv Rust toolchain needs the wasm32-unknown-unknown target:

        ```nix
        languages.rust = {
          enable = true;
          channel = "stable";
          targets = [ "wasm32-unknown-unknown" ];
        };

        outputs.web = config.dioxus.import ./. { };
        ```
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        packages = [
          cfg.package
        ]
        ++ lib.optional cfg.wasm-bindgen.enable cfg.wasm-bindgen.package
        ++ lib.optional cfg.esbuild.enable cfg.esbuild.package
        ++ lib.optional cfg.wasm-opt.enable cfg.wasm-opt.package;

        languages.rust.enable = lib.mkDefault true;

        warnings = rust.wasmTargetWarnings "dx (for the web platform)";
      }

      (lib.mkIf cfg.serve.enable {
        processes.dioxus = {
          # dx finds cargo, wasm-bindgen and the other tools in the shell.
          # It is not interactive here: the process manager owns the terminal.
          exec = "exec ${lib.getExe cfg.package} serve ${
            lib.escapeShellArgs (
              [
                "--addr"
                cfg.serve.host
                "--port"
                (toString config.processes.dioxus.ports.http.value)
                "--open"
                "false"
                "--interactive"
                "false"
              ]
              ++ cfg.serve.extraArgs
            )
          }";

          cwd = "${config.devenv.root}/${cfg.serve.directory}";

          ports.http.allocate = cfg.serve.port;
        };
      })
    ]
  );
}
