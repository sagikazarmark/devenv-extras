{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "ad5bca2669a9dcd9028e25e3b73b09e99893c1af";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-InZ6qTjmO77GojlNzSHY12XM4sj74xBgPC1pI7nhjKA=";
  };

  vendorHash = "sha256-yV6ubM93VyXTVRuqmPAluj+HaCOSnwk7FGmpSG33l5s=";
  proxyVendor = true;

  doCheck = false;
  subPackages = [ "cmd/dang" ];

  meta = {
    description = "Experimental GraphQL scripting language";
    homepage = "https://github.com/vito/dang";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    mainProgram = "dang";
  };
}
