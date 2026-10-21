# Helpers for modules that install tools at the exact version of a package in a lockfile,
# such as a crate in Cargo.lock or an npm package in package-lock.json.
{
  pkgs,
  lib,
  config,
  multiverse,
}:

rec {
  # The Cargo.lock to read versions from: the one set, or the one at the root if it exists.
  cargoLock =
    path:
    if path != null then
      path
    else if builtins.pathExists (config.devenv.root + "/Cargo.lock") then
      config.devenv.root + "/Cargo.lock"
    else
      null;

  # The version of a crate in a Cargo.lock (see `cargoLock`), or null without a Cargo.lock or the crate.
  lockedVersion =
    path: crate:
    let
      lockPath = cargoLock path;
    in
    if lockPath == null then
      null
    else
      let
        lock = builtins.fromTOML (builtins.readFile lockPath);
        package = lib.findFirst (p: p.name == crate) null (lock.package or [ ]);
      in
      if package == null then null else package.version;

  # The package-lock.json to read versions from: the one set, or the one at the root if it exists.
  packageLock =
    path:
    if path != null then
      path
    else if builtins.pathExists (config.devenv.root + "/package-lock.json") then
      config.devenv.root + "/package-lock.json"
    else
      null;

  # The version of an npm package in a package-lock.json (see `packageLock`), or null without a lockfile or the package.
  # The package installed at the root wins over ones installed in workspaces.
  npmLockedVersion =
    path: name:
    let
      lockPath = packageLock path;
    in
    if lockPath == null then
      null
    else
      let
        lock = builtins.fromJSON (builtins.readFile lockPath);
        # lockfileVersion 2 and 3
        packages = lock.packages or { };
        nested = lib.filter (key: lib.hasSuffix "/node_modules/${name}" key) (lib.attrNames packages);
        # lockfileVersion 1
        dependencies = lock.dependencies or { };
      in
      packages."node_modules/${name}".version or (
        if nested != [ ] then
          packages.${lib.head nested}.version or null
        else
          dependencies.${name}.version or null
      );

  # The versions of a package that nixpkgs-multiverse has, or [ ] without the input.
  multiverseVersions =
    attr:
    let
      result = builtins.tryEval (lib.attrNames (multiverse.${attr} or { }));
    in
    if result.success then result.value else [ ];

  # A package at an exact version from nixpkgs-multiverse.
  fromMultiverse =
    attr: version:
    multiverse.${attr}.${version} or (throw "nixpkgs-multiverse has no ${attr} ${version}");

  # A package at an exact version: nixpkgs if it has it, otherwise nixpkgs-multiverse.
  # Nixpkgs keeps some packages at older versions under attributes like `wasm-bindgen-cli_0_2_100`.
  versioned =
    attr: version:
    let
      versionedAttr = "${attr}_${lib.replaceStrings [ "." ] [ "_" ] version}";
    in
    if version == null then
      pkgs.${attr}
    else if pkgs.${attr}.version == version then
      pkgs.${attr}
    else if pkgs ? ${versionedAttr} then
      pkgs.${versionedAttr}
    else
      fromMultiverse attr version;

  cargoLockDescription = crates: ''
    The Cargo.lock to read the ${crates} versions from.
    When null, Cargo.lock at the project root is used if it exists.
  '';

  versionDescription = crate: ''
    The version to install. It must match the `${crate}` crate exactly.
    Defaults to the version of `${crate}` in Cargo.lock, if there is one.
  '';

  sourceDescription = attr: ''
    A version is installed from nixpkgs if it has it, otherwise from nixpkgs-multiverse,
    which needs the `nixpkgs-multiverse` input. When null, `pkgs.${attr}` is installed.
  '';
}
