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
in
{
  options.worker-build = {
    enable = lib.mkEnableOption "worker-build, which builds Rust Cloudflare Workers";

    cargoLock = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = versions.cargoLockDescription "worker";
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
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package ];
  };
}
