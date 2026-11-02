{ pkgs }:

{
  dang = pkgs.callPackage ../modules/languages/dang/package.nix { };
  lightpanda-bin = pkgs.callPackage ./lightpanda-bin.nix { };
  sandbox-agent = pkgs.callPackage ./sandbox-agent.nix { };
}
