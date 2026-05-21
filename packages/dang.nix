{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "4cbbcacc8bd52d941b058602d7af08a68e469ba9";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-huaAP8aT/qtAKvEm4/p81LJxKhJ7/LuhvfZWSJOPiV4=";
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
