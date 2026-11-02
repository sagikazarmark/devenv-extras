{
  config,
  lib,
  pkgs,
  ...
}:

let
  host = pkgs.stdenv.buildPlatform.rust.rustcTarget;

  # Cross-compile for the supported targets other than the host.
  crossTargets = lib.remove host [
    "x86_64-unknown-linux-gnu"
    "aarch64-unknown-linux-gnu"
    "aarch64-apple-darwin"
  ];

  import = config.php-ext-rs.import ./.;

  fails = drv: !(builtins.tryEval drv.drvPath).success;

  php = pkgs.php84;
in
{
  languages.rust = {
    channel = "stable";
    targets = crossTargets;
  };

  languages.php = {
    package = php;
    lsp.enable = false;
  };

  php-ext-rs.enable = true;

  packages = [ pkgs.file ];

  outputs = {
    host = import { inherit php; };
    # NTS and ZTS for the first cross target.
    matrix = config.php-ext-rs.matrix ./. {
      phps = [ php ];
      variants = [
        "nts"
        "zts"
      ];
      targets = [ (builtins.elemAt crossTargets 0) ];
    };
    cross = import {
      inherit php;
      target = builtins.elemAt crossTargets 1;
    };
  };

  # Building the shell builds the outputs, so .test.sh can check them.
  env = {
    PHP_EXT_RS_HOST_LOAD_TEST = config.outputs.host.tests.load;
    PHP_EXT_RS_PHP = php.withExtensions ({ enabled, ... }: enabled ++ [ config.outputs.host ]);
    PHP_EXT_RS_MATRIX = config.outputs.matrix;
    PHP_EXT_RS_CROSS = config.outputs.cross;
    PHP_EXT_RS_CROSS_TARGET = builtins.elemAt crossTargets 1;
  };

  assertions = [
    {
      assertion = config.outputs.host.extensionName == "hello";
      message = "php-ext-rs.import should name the extension after php-ext.extension-name in composer.json.";
    }
    {
      assertion = config.outputs.host.pname == "php-hello";
      message = "php-ext-rs.import should name the package after the extension.";
    }
    {
      assertion =
        let
          builds = config.outputs.matrix.builds;
          target = builtins.elemAt crossTargets 0;
        in
        lib.hasSuffix "-zts" builds."php-${php.version}-zts/${target}".headers.pname
        && !lib.hasSuffix "-zts" builds."php-${php.version}/${target}".headers.pname;
      message = "php-ext-rs.matrix should build ZTS variants against ZTS PHP headers.";
    }
    {
      assertion = fails (import { });
      message = "php-ext-rs.import should require the PHP package to build against.";
    }
    {
      assertion = fails (import {
        inherit php;
        target = "riscv64gc-unknown-linux-gnu";
      });
      message = "php-ext-rs.import should reject targets it cannot configure PHP headers for.";
    }
  ];
}
