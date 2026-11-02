# PHP's headers and php-config for another platform, from PHP's source configured with Zig as the C compiler.
#
# ext-php-rs only needs the headers (and php-config to find them), so PHP is configured but not built:
# a cross build of the whole of PHP needs every library it links for the target.
{
  lib,
  stdenv,
  zig,
  # The PHP to take the source from.
  php,
  # The Zig target to configure for, such as `aarch64-linux-gnu` or `aarch64-macos`.
  zigTarget,
  # The GNU triple to configure for (`--host`), such as `aarch64-unknown-linux-gnu`.
  hostTriple,
  # Whether to configure thread safety (ZTS).
  zts ? false,
}:

stdenv.mkDerivation {
  pname = "php-headers-${zigTarget}${lib.optionalString zts "-zts"}";
  inherit (php.unwrapped or php) version src;

  nativeBuildInputs = [ zig ];

  configureFlags = [
    "--prefix=${placeholder "out"}"
    "--host=${hostTriple}"
    "--build=${stdenv.buildPlatform.config}"
    "--disable-all"
    "--disable-cgi"
    "--disable-cli"
    "--disable-phpdbg"
    "--enable-embed=static"
    "--without-pear"
  ]
  ++ lib.optional zts "--enable-zts"
  # The php-ext-rs Dagger module needs these to configure for x86_64 Linux with Zig on x86_64 Linux,
  # without a known reason. Whether PHP itself uses AVX-512 does not change the extension ABI.
  ++ lib.optionals (lib.hasPrefix "x86_64-linux" zigTarget) [
    "php_cv_have_avx512=no"
    "php_cv_have_avx512vbmi=no"
  ];

  configurePhase = ''
    runHook preConfigure

    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-cache"
    export CC="zig cc -target ${zigTarget}"
    export CXX="zig c++ -target ${zigTarget}"

    ./configure $configureFlags

    runHook postConfigure
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    make install-headers install-programs
    rm -r "$out/php"

    runHook postInstall
  '';

  meta = {
    description = "PHP headers and php-config for ${hostTriple}";
    inherit (php.meta) homepage license;
  };
}
