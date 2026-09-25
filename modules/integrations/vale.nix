{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.vale;
  iniFormat = pkgs.formats.iniWithGlobalSection {
    listToValue = values: lib.concatMapStringsSep ", " toString values;
  };
  absolutePath = path: if lib.hasPrefix "/" path then path else "${config.devenv.root}/${path}";
  configPath = absolutePath cfg.config.file;
  stylesPath = absolutePath cfg.stylesPath;
  seedConfig = cfg.config.settings == null && cfg.config.file == null;
  fileName = if cfg.config.file == null then ".vale.ini" else cfg.config.file;
  defaultSettings = {
    globalSection = {
      MinAlertLevel = "suggestion";
      Packages = [ "Microsoft" ];
    };
    sections."*.md".BasedOnStyles = [
      "Vale"
      "Microsoft"
    ];
  };
in
{
  options.vale = {
    enable = lib.mkEnableOption "Vale prose linter";

    package = lib.mkPackageOption pkgs "vale" { };

    config = {
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.nonEmptyStr;
        default = if cfg.config.settings == null then null else ".vale.ini";
        defaultText = lib.literalExpression ''if config.vale.config.settings == null then null else ".vale.ini"'';
        example = "docs/.vale.ini";
        description = ''
          Path to the Vale configuration file, absolute or relative to the devenv
          root. Null leaves Vale's normal configuration discovery in
          effect. A path is exported as `VALE_CONFIG_PATH` and passed to
          the git hook and sync task. With settings, this is also the generated
          file's location and must be project-relative and nonempty. The selected
          path refers to the project file in every copy mode, not its store source.
          With both file and settings null, a starter is seeded to `.vale.ini`
          independently of config selection. This can take precedence over a
          configuration discovered in a parent directory.
        '';
      };

      settings = lib.mkOption {
        type = lib.types.nullOr iniFormat.type;
        default = null;
        example = lib.literalExpression ''
          {
            globalSection = {
              MinAlertLevel = "suggestion";
              Packages = [ "Microsoft" "./vale-local" ];
            };
            sections."*.md".BasedOnStyles = "Vale, Microsoft";
          }
        '';
        description = ''
          Contents of the Vale configuration file. Put global keys such as
          `StylesPath` and `Packages` in `globalSection`, and file patterns in
          `sections`. Values may be scalars (including strings) or nonempty
          lists, which are rendered as comma-separated values. For example,
          `Packages = [ "Microsoft" "./vale-local" ]` becomes
          `Packages=Microsoft, ./vale-local`.

          When set, devenv generates a writable copy on each shell entry, with
          a header identifying devenv.nix as the source of truth. Commit the
          output for contributors who do not use devenv.

          When both settings and file are null, devenv seeds `.vale.ini` with
          the Vale quickstart's Microsoft and Vale styles for Markdown. The
          file uses `files.".vale.ini".copyMode = "seed"`, preserving existing
          regular files and later edits. An explicit file without settings
          is left untouched. The starter omits `StylesPath` to use devenv's
          styles directory. Run `vale sync` or enable `vale.sync.enable` to
          download its packages before linting.

          Omit
          `StylesPath` to use the directory supplied through `VALE_STYLES_PATH`;
          outside devenv, Vale then uses its normal user-level styles directory.
        '';
      };

      copyMode = lib.mkOption {
        type = lib.types.enum [
          "copy"
          "symlink"
        ];
        default = "copy";
        description = ''
          How to materialize settings as a configuration file. Has no effect
          when settings is null. `copy` overwrites a writable file on shell
          entry, and `symlink` links it to the read-only Nix store. Starter
          configurations always default to seed mode in the `files` module.
        '';
      };
    };

    stylesPath = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "${config.devenv.state}/vale/styles";
      defaultText = lib.literalExpression ''"''${config.devenv.state}/vale/styles"'';
      description = ''
        Default styles directory, exported as `VALE_STYLES_PATH` and created
        on shell entry. Relative paths are resolved from the devenv root.
        An INI `StylesPath` takes precedence, including as the sync destination.
        Omit that INI key to download packages here. Custom styles and
        vocabularies can be installed alongside downloads by listing a local
        directory in the INI `Packages` key.
      '';
    };

    sync = {
      enable = lib.mkEnableOption "vale sync during devenv initialization";

      arguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional command-line arguments passed to vale sync.";
      };
    };

    lsp = {
      enable = lib.mkEnableOption "Vale language server" // {
        default = true;
      };

      package = lib.mkPackageOption pkgs "vale-ls" { };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.config.settings == null || (cfg.config.file != null && !lib.hasPrefix "/" cfg.config.file);
        message = "vale.config.file must be non-null and project-relative when vale.config.settings is set.";
      }
    ];

    packages = [ cfg.package ] ++ lib.optional cfg.lsp.enable cfg.lsp.package;

    env = {
      VALE_STYLES_PATH = stylesPath;
    }
    // lib.optionalAttrs (cfg.config.file != null) {
      VALE_CONFIG_PATH = configPath;
    };

    files = lib.optionalAttrs (seedConfig || (cfg.config.settings != null && cfg.config.file != null)) {
      ${fileName} = {
        copyMode = lib.mkDefault (if seedConfig then "seed" else cfg.config.copyMode);
        source =
          if seedConfig then
            iniFormat.generate "vale.ini" defaultSettings
          else
            pkgs.concatText "vale.ini" [
              (pkgs.writeText "vale-header" "; Generated by devenv. Edit devenv.nix, not this file.\n")
              (iniFormat.generate "vale.ini" cfg.config.settings)
            ];
      };
    };

    git-hooks.hooks.vale = {
      enable = lib.mkDefault true;
      package = cfg.package;
      settings.configPath = lib.optionalString (cfg.config.file != null) (lib.escapeShellArg configPath);
    };

    tasks."devenv:vale:styles" = {
      description = "Create Vale styles directory";
      before = [ "devenv:enterShell" ];
      exec = ''
        mkdir -p ${lib.escapeShellArg stylesPath}
      '';
    };

    tasks."devenv:vale:sync" = lib.mkIf cfg.sync.enable {
      description = "Synchronize Vale styles";
      after = [
        "devenv:files"
        "devenv:vale:styles"
      ];
      before = [ "devenv:enterShell" ];
      cwd = config.devenv.root;
      exec = ''
        ${lib.getExe cfg.package} ${
          lib.optionalString (cfg.config.file != null) "--config ${lib.escapeShellArg configPath}"
        } sync ${lib.escapeShellArgs cfg.sync.arguments}
      '';
    };
  };
}
