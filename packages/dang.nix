{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "dang";
  version = "3252afa462954365236d495b107ad7a25cf4f326";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "dang";
    rev = version;
    hash = "sha256-oJpCH/POjkuYcvBHXRhjIR5h1xnRiTux10SG34eKto8=";
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
