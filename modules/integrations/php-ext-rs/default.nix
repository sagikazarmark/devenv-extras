{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.php-ext-rs;

  rust = import ../../lib/rust.nix { inherit pkgs lib config; };

  # The Rust target of the machine that runs the build.
  hostTarget = pkgs.stdenv.buildPlatform.rust.rustcTarget;

  phpShim = pkgs.callPackage ./php-shim.nix { };

  noXcrun = pkgs.writeShellScriptBin "xcrun" ''
    echo "xcrun is not available in cross builds of PHP extensions" >&2
    exit 1
  '';

  libclangPath = "${lib.getLib pkgs.llvmPackages.libclang}/lib";

  # cargo-zigbuild passes the headers Zig compiles with to bindgen, including Zig's copy of clang's own
  # headers, which only work with the same clang version: use the libclang Zig is built with.
  zigLibclangPath =
    zig:
    let
      libclang = lib.findFirst (input: (input.pname or "") == "clang") pkgs.llvmPackages.libclang (
        zig.buildInputs or [ ]
      );
    in
    # The build inputs are the dev outputs.
    "${libclang.lib or libclang}/lib";

  darwinRustFlags = "-C link-arg=-undefined -C link-arg=dynamic_lookup";

  # The Zig targets PHP headers can be configured for, by Rust target.
  zigTargets = {
    "x86_64-unknown-linux-gnu" = "x86_64-linux-gnu";
    "aarch64-unknown-linux-gnu" = "aarch64-linux-gnu";
    "x86_64-apple-darwin" = "x86_64-macos";
    "aarch64-apple-darwin" = "aarch64-macos";
  };

  # A cross target, split into the Rust target and the glibc version suffix that cargo-zigbuild takes
  # (such as `.2.17`), with the matching Zig target.
  crossTarget =
    target:
    let
      parts = lib.splitString "." target;
      triple = builtins.head parts;
      glibc = lib.concatStringsSep "." (builtins.tail parts);
    in
    if !zigTargets ? ${triple} then
      throw ''
        php-ext-rs.import cannot build for ${target}. It builds for the host target (${hostTarget}) and
        cross-compiles for ${lib.concatStringsSep ", " (builtins.attrNames zigTargets)}.
      ''
    else
      {
        inherit triple;
        zigTarget = zigTargets.${triple} + lib.optionalString (glibc != "") ".${glibc}";
        darwin = lib.hasSuffix "-apple-darwin" triple;
      };

  # PIE metadata in composer.json: https://github.com/php/pie/blob/main/docs/extension-maintainers.md
  phpExtMetadata =
    path:
    let
      composerJson = path + "/composer.json";
    in
    if builtins.pathExists composerJson then
      (builtins.fromJSON (builtins.readFile composerJson)).php-ext or { }
    else
      { };

  # `buildRustPackage` arguments: the crate in composer.json's `build-path` by default.
  buildArgsFor =
    path: args:
    let
      buildPath = (phpExtMetadata path).build-path or null;
    in
    lib.optionalAttrs (buildPath != null && buildPath != ".") { buildAndTestSubdir = buildPath; }
    // builtins.removeAttrs args [
      "php"
      "target"
      "extensionName"
    ];

  extensionNameFor =
    path: args:
    args.extensionName or (phpExtMetadata path).extension-name
      or (lib.replaceStrings [ "-" ] [ "_" ] (rust.cargoProject path (buildArgsFor path args)).pname);

  missingPhp = name: ''
    ${name} needs the PHP package to build the extension for, for example:

      config.${name} ./. { php = pkgs.php84; }

    The extension only loads into a PHP with the same version, thread safety (ZTS) and debug mode.
    `config.languages.php.package` works too, unless the extension is also loaded into it.
  '';

  # Build for the host target with build.nix and the devenv Rust toolchain: no Zig, and bindgen uses the
  # nixpkgs clang.
  buildForHost =
    path: args: php: extensionName:
    let
      buildArgs = buildArgsFor path args;

      build = pkgs.callPackage ./build.nix {
        rustPlatform = rust.rustPlatformFor "php-ext-rs.import" hostTarget buildArgs;
      };
    in
    build (
      rust.cargoProject path buildArgs
      // builtins.removeAttrs buildArgs [ "rustPlatform" ]
      // {
        inherit php extensionName;
        pname = "php-${extensionName}";
      }
    );

  # Cross-compile with rust-cross (cargo-zigbuild), against PHP headers configured with Zig for the target.
  buildForTarget =
    path: args: php: extensionName: target:
    let
      inherit (crossTarget target) triple zigTarget darwin;

      zig = config.languages.zig.package;

      headers = pkgs.callPackage ./php-headers.nix {
        inherit zig php zigTarget;
        hostTriple = triple;
        zts = php.ztsSupport or false;
      };

      cargoTargetEnv = lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] triple);
    in
    config.rust-cross.import path (
      buildArgsFor path args
      // {
        inherit target;
        pname = "php-${extensionName}-${triple}";

        env = {
          PHP = lib.getExe' phpShim "php";
          PHP_CONFIG = "${headers}/bin/php-config";
          LIBCLANG_PATH = zigLibclangPath zig;
        }
        // lib.optionalAttrs darwin {
          # PHP symbols are resolved by the PHP process that loads the extension.
          "CARGO_TARGET_${cargoTargetEnv}_RUSTFLAGS" = darwinRustFlags;
        }
        // args.env or { };

        preBuild =
          lib.optionalString (!darwin && pkgs.stdenv.buildPlatform.isDarwin) ''
            # ext-php-rs's build script passes the macOS SDK from `xcrun --show-sdk-path` to bindgen when it
            # runs on macOS, whatever the target. Without xcrun it leaves it out.
            export PATH="${noXcrun}/bin:$PATH"
          ''
          + args.preBuild or "";

        postInstall =
          import ./install-extension.nix (if darwin then ".dylib" else ".so") extensionName
          + args.postInstall or "";

        passthru = {
          inherit extensionName php headers;
        }
        // args.passthru or { };
      }
    );

  importExtension =
    path: args:
    let
      php = args.php or (throw (missingPhp "php-ext-rs.import"));
      target = args.target or hostTarget;
      extensionName = extensionNameFor path args;
    in
    if target == hostTarget then
      buildForHost path args php extensionName
    else
      buildForTarget path args php extensionName target;

  # The PHP package for a variant: "nts" or "zts".
  phpVariant =
    php: variant:
    let
      zts =
        {
          nts = false;
          zts = true;
        }
        .${variant} or (throw "php-ext-rs.matrix: unknown variant ${variant}, expected \"nts\" or \"zts\"");
    in
    if (php.ztsSupport or false) == zts then php else php.override { ztsSupport = zts; };

  matrix =
    path:
    {
      phps ? throw (missingPhp "php-ext-rs.matrix"),
      variants ? [ "nts" ],
      targets ? [ hostTarget ],
      ...
    }@args:
    let
      extensionName = extensionNameFor path args;

      extensionArgs = builtins.removeAttrs args [
        "phps"
        "variants"
        "targets"
      ];

      builds = lib.listToAttrs (
        lib.concatMap (
          php:
          lib.concatMap (
            variant:
            map (
              target:
              lib.nameValuePair "php-${php.version}${lib.optionalString (variant == "zts") "-zts"}/${target}" (
                importExtension path (
                  extensionArgs
                  // {
                    inherit target extensionName;
                    php = phpVariant php variant;
                  }
                )
              )
            ) targets
          ) variants
        ) phps
      );
    in
    pkgs.linkFarm "php-${extensionName}-matrix" (
      lib.mapAttrsToList (dir: build: {
        name = "${dir}/${extensionName}.so";
        path = "${build}/lib/php/extensions/${extensionName}.so";
      }) builds
    )
    // {
      inherit builds;
    };

  phpUnwrapped = cfg.php.unwrapped or cfg.php;
in
{
  options.php-ext-rs = {
    enable = lib.mkEnableOption "development of PHP extensions written in Rust with ext-php-rs";

    php = lib.mkOption {
      type = lib.types.package;
      default = config.languages.php.package;
      defaultText = lib.literalExpression "config.languages.php.package";
      description = ''
        The PHP that `cargo build` builds extensions against in the shell.

        `import` and `matrix` do not use it: they take the PHP to build against as an argument.
      '';
    };

    import = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      readOnly = true;
      default = importExtension;
      defaultText = lib.literalMD "a function that builds a PHP extension written in Rust";
      description = ''
        Build a PHP extension written in Rust with [ext-php-rs](https://github.com/extphprs/ext-php-rs)
        for one PHP package and target, for example to use it in `outputs`.

        It takes the path to the project (the directory with Cargo.lock) and an attribute set of
        arguments, and returns a package with the extension in `lib/php/extensions/<name>.so`, which
        nixpkgs' `php.withExtensions` and `php.buildEnv` load. Dependencies are vendored from
        Cargo.lock, so the build runs offline.

        The arguments are:

        - `php` (required): the PHP package to build against, such as `pkgs.php84` or
          `pkgs.php84.override { ztsSupport = true; }`. The extension only loads into a PHP with the
          same version, thread safety (ZTS) and debug mode. `config.languages.php.package` works too,
          unless the extension is also added to it, which would make the PHP depend on itself.
        - `target`: the Rust target to build for. The default is the host target.
        - `extensionName`: the name of the extension file. The default is `php-ext.extension-name` in
          composer.json, or the crate name with `-` replaced by `_`.
        - `rustPlatform`: the `rustPlatform` to build with, instead of one with the devenv Rust toolchain.

        Other arguments, such as `buildFeatures`, `cargoBuildFlags` or `buildAndTestSubdir` (by
        default `php-ext.build-path` in composer.json), are passed to `rustPlatform.buildRustPackage`.

        A build for the host target uses the devenv Rust toolchain and nixpkgs' C compiler.
        Builds for other targets cross-compile like `rust-cross.import`: PHP's source is configured
        for the target with Zig to get its headers, and the extension is built with cargo-zigbuild.
        They support `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` (with a glibc
        version suffix such as `.2.17`), and `x86_64-apple-darwin` and `aarch64-apple-darwin`. The
        devenv Rust toolchain needs the target:

        ```nix
        languages.rust = {
          enable = true;
          channel = "stable";
          targets = [ "aarch64-unknown-linux-gnu" ];
        };

        outputs = {
          ext = config.php-ext-rs.import ./. { php = pkgs.php84; };
          ext-aarch64-linux = config.php-ext-rs.import ./. {
            php = pkgs.php84;
            target = "aarch64-unknown-linux-gnu.2.17";
          };
        };
        ```
      '';
    };

    matrix = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      readOnly = true;
      default = matrix;
      defaultText = lib.literalMD "a function that builds a PHP extension written in Rust for several PHP versions and targets";
      description = ''
        Build a PHP extension written in Rust for every combination of PHP packages, thread safety
        variants and targets, with `import`.

        It returns a directory with `php-<version>[-zts]/<target>/<name>.so` for each build, and the
        builds in its `builds` attribute. The arguments are:

        - `phps` (required): the PHP packages to build against, such as `[ pkgs.php84 pkgs.php85 ]`.
        - `variants`: `"nts"` and `"zts"` (thread safe) builds of each PHP. The default is `[ "nts" ]`.
          A ZTS build for the host target needs PHP built with ZTS, which nixpkgs does not cache.
        - `targets`: the Rust targets to build for. The default is the host target.

        Other arguments are passed to `import`:

        ```nix
        outputs.ext = config.php-ext-rs.matrix ./. {
          phps = [ pkgs.php84 pkgs.php85 ];
          variants = [ "nts" "zts" ];
          targets = [ "x86_64-unknown-linux-gnu" "aarch64-unknown-linux-gnu" "aarch64-apple-darwin" ];
        };
        ```
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    languages.rust.enable = lib.mkDefault true;
    languages.php.enable = lib.mkDefault true;

    # ext-php-rs runs `php -i` and `php-config --includes`, and bindgen needs libclang.
    env = {
      PHP = lib.getExe' cfg.php "php";
      PHP_CONFIG = "${lib.getDev phpUnwrapped}/bin/php-config";
      LIBCLANG_PATH = libclangPath;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      # libclang is not wrapped like the nixpkgs C compiler, so it needs the C library headers.
      # On macOS, ext-php-rs passes the SDK from xcrun.
      BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${lib.getDev pkgs.stdenv.cc.libc}/include";
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      # PHP symbols are resolved by the PHP process that loads the extension.
      "CARGO_TARGET_${pkgs.stdenv.hostPlatform.rust.cargoEnvVarTarget}_RUSTFLAGS" = darwinRustFlags;
    };
  };
}
