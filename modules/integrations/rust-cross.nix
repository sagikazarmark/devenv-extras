{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.rust-cross;

  rust = import ../lib/rust.nix { inherit pkgs lib config; };

  # cargo-zigbuild before 0.24.0 cannot link cdylibs for macOS with Zig 0.16 or later:
  # https://github.com/rust-cross/cargo-zigbuild/issues/479
  # Build 0.24.0 until nixpkgs has it.
  cargoZigbuild =
    let
      zigbuild = pkgs.cargo-zigbuild.override { zig = config.languages.zig.package; };
    in
    if lib.versionAtLeast zigbuild.version "0.24.0" then
      zigbuild
    else
      zigbuild.overrideAttrs (
        finalAttrs: _prev: {
          version = "0.24.0";

          src = pkgs.fetchFromGitHub {
            owner = "rust-cross";
            repo = "cargo-zigbuild";
            tag = "v${finalAttrs.version}";
            hash = "sha256-7hwu7rOotkpm+nRLQq0a44e+2UmPJyRo7tzeRX5K8tE=";
          };

          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit (finalAttrs) pname version src;
            hash = "sha256-QBsZEP8er3tTF9zGBD2UPiZwsXBf6Hy0t+du56gQprg=";
          };

          # The linker tests write cargo-zigbuild's cache to $HOME.
          preCheck = ''
            export HOME="$TMPDIR/home"
          '';
        }
      );

  # The Rust target of the machine that runs the build.
  # Builds for it use plain `cargo build`; builds for any other target use cargo-zigbuild.
  hostTarget = pkgs.stdenv.buildPlatform.rust.rustcTarget;

  # A `--target` value without cargo-zigbuild's glibc version suffix (such as `.2.17`),
  # or null for a custom target specification file, which is not part of a toolchain.
  targetTriple =
    target: if lib.hasSuffix ".json" target then null else builtins.head (lib.splitString "." target);

  checkTarget =
    target: hasRustPlatform:
    let
      triple = targetTriple target;
    in
    if target == "universal2-apple-darwin" then
      throw ''
        rust-cross.import does not support universal2-apple-darwin: cargo-zigbuild does not report its artifacts.
        Build x86_64-apple-darwin and aarch64-apple-darwin separately instead.
      ''
    else if !hasRustPlatform && triple != null && triple != hostTarget && !rust.hasTarget triple then
      throw ''
        rust-cross.import builds for ${triple}, but the devenv Rust toolchain does not have the target. Add it with:

        ${rust.rustSnippet triple}
        or pass a `rustPlatform` argument.
      ''
    else
      target;

  # Copy the binaries and libraries of the workspace packages that cargo reports in its JSON messages.
  installArtifacts = ''
    members="$(cargo metadata --offline --no-deps --format-version 1 | jq -c '.workspace_members')"

    jq -r --argjson members "$members" '
      select(.reason == "compiler-artifact" and (.package_id as $id | $members | index($id)))
      | .executable // empty
    ' "$TMPDIR/cargo-messages.json" | while IFS= read -r file; do
      install -Dm755 "$file" "$out/bin/$(basename "$file")"
    done

    jq -r --argjson members "$members" '
      select(.reason == "compiler-artifact" and (.package_id as $id | $members | index($id)))
      | select(.target.kind | any(. == "cdylib" or . == "dylib" or . == "staticlib"))
      | .filenames[]
      | select(test("\\.(rlib|rmeta)$") | not)
    ' "$TMPDIR/cargo-messages.json" | while IFS= read -r file; do
      install -Dm644 "$file" "$out/lib/$(basename "$file")"
    done

    if [ ! -d "$out" ]; then
      echo "cargo built no binaries or libraries" >&2
      exit 1
    fi
  '';
in
{
  options.rust-cross = {
    enable = lib.mkEnableOption "cross-compilation of Rust projects with cargo-zigbuild";

    package = lib.mkOption {
      type = lib.types.package;
      default = cargoZigbuild;
      defaultText = lib.literalMD "`pkgs.cargo-zigbuild` (at least 0.24.0) with the Zig compiler from `languages.zig.package`";
      description = ''
        The cargo-zigbuild package, which `import` also builds with.

        The default uses the Zig compiler from `languages.zig.package`. It builds cargo-zigbuild 0.24.0
        when nixpkgs has an older version, which cannot link `cdylib` crates for macOS with Zig 0.16 or later.
      '';
    };

    import = lib.mkOption {
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      readOnly = true;
      default =
        path:
        {
          target,
          release ? true,
          cargoBuildFlags ? [ ],
          ...
        }@args:
        let
          checkedTarget = checkTarget target (args ? rustPlatform);
          triple = targetTriple target;
          command = if checkedTarget == hostTarget then "build" else "zigbuild";
          darwin = triple != null && lib.hasSuffix "-apple-darwin" triple;
        in
        rust.importCargo
          {
            name = "rust-cross.import";
            target = if triple != null then triple else target;
            pnameSuffix = "-${if triple != null then triple else "custom"}";
            nativeBuildInputs = [
              cfg.package
              pkgs.jq
            ];

            buildCommand = ''
              cargo ${
                lib.escapeShellArgs (
                  [
                    command
                    "--target"
                    checkedTarget
                    "--message-format"
                    "json-render-diagnostics"
                  ]
                  ++ lib.optional release "--release"
                  ++ rust.featureFlags args
                  ++ cargoBuildFlags
                )
              } > "$TMPDIR/cargo-messages.json"
            '';

            installCommand = installArtifacts;
          }
          path
          (
            builtins.removeAttrs args [
              "target"
              "release"
            ]
            // lib.optionalAttrs (darwin && config.apple.sdk != null) {
              # cargo-zigbuild links macOS targets against the SDK in SDKROOT, which the SDK's setup hook sets.
              buildInputs = [ config.apple.sdk ] ++ args.buildInputs or [ ];
            }
          );
      defaultText = lib.literalMD "a function that cross-compiles a Cargo project for one target";
      description = ''
        Build a Cargo project for one Rust target, for example to use it in `outputs`.

        It takes the path to the project (the directory with Cargo.lock) and an attribute set of
        arguments, and returns a package with the binaries of the workspace packages in `bin` and their
        `cdylib`, `dylib` and `staticlib` libraries in `lib`. Dependencies are vendored from Cargo.lock,
        so the build runs offline.

        A build for the host target uses `cargo build`. Builds for any other target use
        `cargo zigbuild`, which links with Zig, so no C toolchain for the target is needed.

        The arguments are:

        - `target`: the Rust target to build for, such as `"aarch64-unknown-linux-musl"`.
          `*-linux-gnu` targets take a glibc version suffix, such as `"x86_64-unknown-linux-gnu.2.17"`.
        - `release`: build with `--release` (the default) or without it.
        - `buildFeatures` and `buildNoDefaultFeatures`: the cargo features to build with.
        - `cargoBuildFlags`: more flags for cargo, such as `[ "--bin" "server" ]`.
        - `rustPlatform`: the `rustPlatform` to build with, instead of one with the devenv Rust toolchain.

        Other arguments, such as `buildAndTestSubdir` for a crate in a workspace subdirectory or
        `buildInputs`, are passed to `rustPlatform.buildRustPackage`.

        The devenv Rust toolchain needs the target (without the glibc version suffix).
        Build one package per target:

        ```nix
        languages.rust = {
          enable = true;
          channel = "stable";
          targets = [
            "x86_64-unknown-linux-musl"
            "aarch64-unknown-linux-gnu"
          ];
        };

        outputs = {
          app-x86_64-linux = config.rust-cross.import ./. { target = "x86_64-unknown-linux-musl"; };
          app-aarch64-linux = config.rust-cross.import ./. { target = "aarch64-unknown-linux-gnu.2.17"; };
        };
        ```

        Builds for macOS targets link against the SDK in `apple.sdk` on macOS. On Linux there is no
        SDK, so only crates that do not link Apple frameworks build for macOS.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package ];

    languages.rust.enable = lib.mkDefault true;

    languages.zig = {
      enable = lib.mkDefault true;
      # cargo-zigbuild only needs the compiler.
      lsp.enable = lib.mkDefault false;
    };
  };
}
