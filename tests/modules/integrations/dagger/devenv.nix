{ config, pkgs, ... }:

{
  dagger = {
    enable = true;
    package = pkgs.hello;
  };

  assertions = [
    {
      assertion = config.languages.dang.enable;
      message = "dagger.enable should enable languages.dang.";
    }
    {
      assertion = pkgs ? dang;
      message = "The dang overlay did not add pkgs.dang.";
    }
    {
      assertion = config.languages.dang.package == pkgs.dang;
      message = "dagger.enable should keep languages.dang.package at pkgs.dang by default.";
    }
    {
      assertion = config.dagger.package == pkgs.hello;
      message = "dagger.package should use the configured package.";
    }
    {
      assertion = builtins.elem config.dagger.package config.packages;
      message = "dagger.enable should add dagger.package to packages.";
    }
  ];
}
