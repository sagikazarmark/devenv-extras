{ pkgs }:

{
  dang = pkgs.callPackage ./dang.nix { };
  sandbox-agent = pkgs.callPackage ./sandbox-agent.nix { };
}
