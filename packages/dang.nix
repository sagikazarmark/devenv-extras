{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "bfe66140e7385d40c39260c74b9e8d0db0462631";
  # version = "v2.1.1";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-VthCiWC+LOdDdjDD9ybJOebyibWat1xnvPsM2c2g/tk=";
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
