# Helpers for modules that build a Cargo project with a CLI that runs cargo itself, such as dx or worker-build.
{
  pkgs,
  lib,
  config,
}:

let
  rust = config.languages.rust;

  wasmTarget = "wasm32-unknown-unknown";

  rustSnippet = ''
    languages.rust = {
      enable = true;
      channel = "stable";
      targets = [ "${wasmTarget}" ];
    };
  '';
in
{
  # A warning for when the devenv Rust toolchain cannot build WebAssembly.
  # A toolchain file is not checked: it may list the target itself.
  wasmTargetWarnings =
    tool:
    lib.optional (rust.enable && rust.toolchainFile == null && !builtins.elem wasmTarget rust.targets)
      ''
        ${tool} builds WebAssembly, but the devenv Rust toolchain does not have the ${wasmTarget} target. Add it with:

        ${rustSnippet}
      '';

  # Build the Cargo project at `path` with `buildRustPackage`, running `buildCommand` in the crate directory
  # instead of cargo, and `installCommand` to copy its output to `$out`.
  # Dependencies are vendored from Cargo.lock, so the build runs offline.
  #
  # `args` are passed to `buildRustPackage` and override the defaults, except `nativeBuildInputs` and `env`,
  # which are added to them. `args.rustPlatform` replaces the one made from the devenv Rust toolchain.
  importCargo =
    {
      name,
      nativeBuildInputs,
      buildCommand,
      installCommand,
      env ? { },
    }:
    path: args:
    let
      toolchain =
        if !rust.enable then
          throw ''
            ${name} needs the devenv Rust toolchain with the ${wasmTarget} target:

            ${rustSnippet}
            or a `rustPlatform` argument.
          ''
        else
          rust.toolchainPackage;

      rustPlatform =
        args.rustPlatform or (pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        });

      readManifest =
        manifest:
        if builtins.pathExists manifest then builtins.fromTOML (builtins.readFile manifest) else { };

      cargoToml = readManifest (path + "/${args.buildAndTestSubdir or "."}/Cargo.toml");

      # A workspace member can inherit its version (`version.workspace = true`) from the root manifest.
      version =
        let
          ownVersion = cargoToml.package.version or null;
        in
        if builtins.isString ownVersion then
          ownVersion
        else
          (readManifest (path + "/Cargo.toml")).workspace.package.version or "0.0.0";

      crateDir = lib.escapeShellArg (args.buildAndTestSubdir or ".");
    in
    rustPlatform.buildRustPackage (
      {
        pname = cargoToml.package.name or (baseNameOf (toString path));
        inherit version;

        # Leave out devenv state and build outputs, so importing ./. does not copy them to the store.
        src = lib.cleanSourceWith {
          src = path;
          filter =
            name: type:
            lib.cleanSourceFilter name type
            && !builtins.elem name (
              map (dir: "${toString path}/${dir}") [
                ".devenv"
                ".direnv"
                "target"
              ]
            );
        };
        cargoLock.lockFile = path + "/Cargo.lock";

        buildPhase = ''
          runHook preBuild

          # The CLIs write caches and settings to $HOME.
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"

          (cd ${crateDir} && ${buildCommand})

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          (cd ${crateDir} && ${installCommand})

          runHook postInstall
        '';

        # cargo test would build for the host, not for the CLI's targets.
        doCheck = false;
        dontCargoBuild = true;
        dontCargoInstall = true;
      }
      // builtins.removeAttrs args [ "rustPlatform" ]
      // {
        nativeBuildInputs = nativeBuildInputs ++ args.nativeBuildInputs or [ ];
        env = env // args.env or { };
      }
    );

  # cargo's feature flags for `buildRustPackage`'s `buildFeatures` and `buildNoDefaultFeatures` arguments.
  featureFlags =
    args:
    lib.concatMap (feature: [
      "--features"
      feature
    ]) (args.buildFeatures or [ ])
    ++ lib.optional (args.buildNoDefaultFeatures or false) "--no-default-features";
}
