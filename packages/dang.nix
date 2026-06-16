{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "bfbce2f4302cb9b11d2809e9e6fa59b575b0de95";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-Z3UBuXXGaCzUKF4+jjPIAeZuLNNYIMIuWuLgiyrK2uc=";
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
