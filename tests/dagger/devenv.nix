{ config, pkgs, ... }:

{
  dagger.enable = true;

  assertions = [
    {
      assertion = config.languages.dang.enable;
      message = "dagger.enable should enable languages.dang.";
    }
    {
      assertion = config.languages.dang.package == pkgs.dang;
      message = "dagger.enable should keep languages.dang.package at pkgs.dang by default.";
    }
    {
      assertion = config.dagger.package != null;
      message = "dagger.package should evaluate to a package.";
    }
    {
      assertion = builtins.elem config.dagger.package config.packages;
      message = "dagger.enable should add dagger.package to packages.";
    }
  ];
}
