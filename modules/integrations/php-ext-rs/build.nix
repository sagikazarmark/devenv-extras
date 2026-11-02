# Build a PHP extension written in Rust with ext-php-rs, for one PHP package.
#
# It is `rustPlatform.buildRustPackage` with the PHP that ext-php-rs builds against (`php`) and the name of
# the extension (`extensionName`). The extension is installed as `lib/php/extensions/<extensionName>.so`,
# where nixpkgs' `php.withExtensions` and `php.buildEnv` look for it:
#
#   pkgs.php84.withExtensions ({ enabled, ... }: enabled ++ [ myExtension ])
#
# The extension only loads into a PHP with the same API version, thread safety (ZTS) and debug mode
# as `php`, so build one per PHP package.
{
  lib,
  stdenv,
  rustPlatform,
  buildPackages,
  runCommand,
}:

lib.extendMkDerivation {
  constructDrv = rustPlatform.buildRustPackage;

  excludeDrvArgNames = [
    "php"
    "extensionName"
  ];

  extendDrvArgs =
    finalAttrs:
    {
      php,
      extensionName,
      nativeBuildInputs ? [ ],
      env ? { },
      postInstall ? "",
      passthru ? { },
      ...
    }@args:
    let
      phpUnwrapped = php.unwrapped or php;

      runsOnBuildPlatform = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

      # ext-php-rs asks `php -i` about the PHP it builds against. A PHP for another platform cannot
      # run, so a shim answers from its headers instead.
      phpBinary =
        if runsOnBuildPlatform then
          lib.getExe' phpUnwrapped "php"
        else
          lib.getExe' (buildPackages.callPackage ./php-shim.nix { }) "php";

      sharedLibrary = stdenv.hostPlatform.extensions.sharedLibrary;
    in
    {
      pname = args.pname or "php-${extensionName}";

      nativeBuildInputs = [ rustPlatform.bindgenHook ] ++ nativeBuildInputs;

      env = {
        PHP = phpBinary;
        PHP_CONFIG = "${lib.getDev phpUnwrapped}/bin/php-config";
      }
      // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
        # PHP symbols are resolved by the PHP process that loads the extension.
        "CARGO_TARGET_${stdenv.hostPlatform.rust.cargoEnvVarTarget}_RUSTFLAGS" =
          "-C link-arg=-undefined -C link-arg=dynamic_lookup";
      }
      // env;

      # Tests of a cdylib crate link against PHP symbols that only a PHP process provides.
      doCheck = args.doCheck or false;

      postInstall = import ./install-extension.nix sharedLibrary extensionName + postInstall;

      passthru = {
        inherit extensionName php;

        tests =
          lib.optionalAttrs runsOnBuildPlatform {
            # PHP reports an extension it cannot load as a startup error and still exits 0,
            # so compare the loaded modules with and without the extension.
            load = runCommand "${finalAttrs.pname}-load-test" { } ''
              php=${lib.getExe' phpUnwrapped "php"}
              extension=${finalAttrs.finalPackage}/lib/php/extensions/${extensionName}.so

              "$php" -n -m | sort > before
              "$php" -n -d display_errors=stderr -d display_startup_errors=1 -d "extension=$extension" -m \
                2> errors | sort > after

              if [ -s errors ]; then
                cat errors >&2
                exit 1
              fi

              comm -13 before after | grep -v '^$' > $out || true
              if [ "$(wc -l < $out)" -ne 1 ]; then
                echo "expected PHP to load one new module from ${extensionName}, got:" >&2
                cat $out >&2
                exit 1
              fi
            '';
          }
          // passthru.tests or { };
      }
      // removeAttrs passthru [ "tests" ];
    };
}
