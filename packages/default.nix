{ pkgs }:

{
  dang = pkgs.callPackage ../modules/languages/dang/package.nix { };
  sandbox-agent = pkgs.callPackage ./sandbox-agent.nix { };
}
