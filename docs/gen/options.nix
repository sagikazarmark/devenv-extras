{
  pkgs,
  lib ? pkgs.lib,
}:

let
  docsPkgs = pkgs.extend (final: _prev: import ../../packages { pkgs = final; });

  evaluated = lib.evalModules {
    specialArgs = {
      pkgs = docsPkgs;
    };

    modules = [
      ../../modules/default.nix
      (
        { lib, pkgs, ... }:
        {
          options.lib.getInput = lib.mkOption {
            type = lib.types.functionTo lib.types.anything;
            default = _args: {
              packages.${pkgs.stdenv.hostPlatform.system}.dagger = pkgs.hello;
            };
            visible = false;
          };

          options.packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            visible = false;
          };

          options.processes = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { ... }:
                {
                  options = {
                    exec = lib.mkOption {
                      type = lib.types.str;
                      default = "";
                      visible = false;
                    };

                    env = lib.mkOption {
                      type = lib.types.attrsOf lib.types.str;
                      default = { };
                      visible = false;
                    };

                    ports = lib.mkOption {
                      type = lib.types.attrsOf (
                        lib.types.submodule (
                          { config, ... }:
                          {
                            options = {
                              allocate = lib.mkOption {
                                type = lib.types.int;
                                default = 0;
                                visible = false;
                              };

                              value = lib.mkOption {
                                type = lib.types.int;
                                default = config.allocate;
                                visible = false;
                              };
                            };
                          }
                        )
                      );
                      default = { };
                      visible = false;
                    };

                    ready = lib.mkOption {
                      type = lib.types.attrsOf lib.types.anything;
                      default = { };
                      visible = false;
                    };
                  };
                }
              )
            );
            default = { };
            visible = false;
          };
        }
      )
    ];
  };

  publicOptions = builtins.removeAttrs evaluated.options [
    "_module"
    "lib"
    "packages"
    "processes"
  ];

  rewriteDeclaration = declaration:
    let
      path = toString declaration;
      repoPrefix = "${toString ../..}/";
      isRepoLocal = lib.hasPrefix repoPrefix path;
      relativePath =
        if isRepoLocal then
          lib.removePrefix repoPrefix path
        else
          builtins.baseNameOf path;
    in
    {
      name = relativePath;
      url =
        if isRepoLocal then
          "../../${relativePath}"
        else
          relativePath;
    };

  optionsDoc = docsPkgs.nixosOptionsDoc {
    options = publicOptions;
    transformOptions = option: option // {
      declarations = map rewriteDeclaration option.declarations;
    };
    warningsAreErrors = true;
  };
in
  docsPkgs.runCommand "devenv-extras-options.md" { } ''
    cp ${optionsDoc.optionsCommonMark} $out
  ''
