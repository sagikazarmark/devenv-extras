{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "9689d13e8a993b4a35fce865cdeda283dfe17565";
  # version = "v2.1.1";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-CJRvbNDWwmHVkgFZN7A2EF+8UkdzNGAC0kMAgzeXCyE=";
  };

  vendorHash = "sha256-mFzpZ5mxo1mkUsU7rFkT2u6KI7GQS9cE6lRYH3q5KGI=";
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
