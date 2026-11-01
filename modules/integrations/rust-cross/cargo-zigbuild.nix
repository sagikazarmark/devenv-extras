# cargo-zigbuild from its prebuilt release binaries, wrapped with a Zig compiler.
#
# nixpkgs' cargo-zigbuild before 0.24.0 cannot link cdylibs for macOS with Zig 0.16 or later:
# https://github.com/rust-cross/cargo-zigbuild/issues/479
# The prebuilt binary does not depend on Zig, so changing the compiler only rebuilds the wrapper.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zig,
}:

let
  version = "0.24.0";

  sources = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-yI+bnaNctnsVHa1DhGFPdpsbK10wYw44HE6cKyjtNJ4=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-CexU/6fnPzk+1gECuYQjjUAnFHQj422hf7GNZsVvjcs=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-3kJiaYX0KAMweN/BKsilnucT+OVicjXsiDsciZvuiVw=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-PKJe5DSPmr0JMu1N6+gm0kbiD7YW0CAd5b0F5/ll6dk=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;

  source =
    sources.${system} or (throw "cargo-zigbuild ${version} has no prebuilt binary for ${system}");

  meta = {
    description = "Tool to compile Cargo projects with zig as the linker";
    homepage = "https://github.com/rust-cross/cargo-zigbuild";
    license = lib.licenses.mit;
    mainProgram = "cargo-zigbuild";
    platforms = lib.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "cargo-zigbuild-unwrapped";
    inherit version meta;

    src = fetchurl {
      url = "https://github.com/rust-cross/cargo-zigbuild/releases/download/v${version}/cargo-zigbuild-${source.target}.tar.xz";
      inherit (source) hash;
    };

    # The Linux binaries link against glibc and libgcc_s.
    nativeBuildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;
    buildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux stdenv.cc.cc.lib;

    installPhase = ''
      runHook preInstall

      install -Dm755 cargo-zigbuild "$out/bin/cargo-zigbuild"

      runHook postInstall
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "cargo-zigbuild";
  inherit version meta;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    makeWrapper ${lib.getExe unwrapped} "$out/bin/cargo-zigbuild" \
      --prefix PATH : ${lib.makeBinPath [ zig ]}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/cargo-zigbuild" --version | grep -q ${lib.escapeShellArg version}

    runHook postInstallCheck
  '';

  passthru = { inherit unwrapped; };
}
