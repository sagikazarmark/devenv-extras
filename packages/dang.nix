{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "4dc9b32d92383ca3578fcde16770fd4b3525b709";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-4PeBtxvGLWTIedL1f02/djZl/lcjq1dywPeSb/A4/DI=";
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
