{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "076d1827677e81ffd7e2d509d9733e25e3e5fc67";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-OCykNa7d71GVtYK9n7e0feHtszVMRjJUFbU55Bg38ac=";
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
