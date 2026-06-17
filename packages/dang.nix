{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "v2.1.1";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-Y/u5TWvJM+k1IbtVYWqo0INSYnb2tUNLRLk3PzWxz1o=";
  };

  vendorHash = "sha256-t/Lik2quiLorvi+BA44X9I46/XRNkWbkViDEDzn9n0M=";
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
