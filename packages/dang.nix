{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "07bc53ad0d726539a071183e84b9c2723843a8bd";
  # version = "v2.1.1";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-rtX12uuc5mAgY1dQdPPbesFTE/IgxEvGCOR1sHybZ84=";
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
