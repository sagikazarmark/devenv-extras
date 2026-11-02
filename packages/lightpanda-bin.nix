{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "1.0.2";
  baseUrl = "https://github.com/lightpanda-io/browser/releases/download/${version}";

  supportedSystems = {
    aarch64-darwin = {
      target = "aarch64-macos";
      hash = "sha256-nz7nSaVdGrxfj92g2VWcOyq87Fv/W/6QK8BsColTjsQ=";
    };
    x86_64-darwin = {
      target = "x86_64-macos";
      hash = "sha256-kad17MZ5N9jXnBsaMVdI5SFXgE8Y9inG4cYzKkYlX8Y=";
    };
    x86_64-linux = {
      target = "x86_64-linux";
      hash = "sha256-rn0B0mHvueSA4YzjQkUzMyiDhjvPcLEqQyG1cz834Z4=";
    };
    aarch64-linux = {
      target = "aarch64-linux";
      hash = "sha256-rFRt/EPFM0MNqSt1qzbyop2n1jJNXTi69gbvLg2Ek0U=";
    };
  };

  system = stdenv.hostPlatform.system;
  systemInfo =
    supportedSystems.${system} or (throw "lightpanda-bin ${version} is not packaged for ${system}");
in
stdenv.mkDerivation {
  pname = "lightpanda-bin";
  inherit version;

  src = fetchurl {
    url = "${baseUrl}/lightpanda-${systemInfo.target}";
    hash = systemInfo.hash;
  };

  dontUnpack = true;

  # The Linux binaries only link against glibc, at the FHS path of its dynamic linker.
  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;

  # Stripping would invalidate the macOS code signature.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -D -m 0755 "$src" "$out/bin/lightpanda"

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    LIGHTPANDA_DISABLE_TELEMETRY=true "$out/bin/lightpanda" version | grep -qx ${lib.escapeShellArg version}

    runHook postInstallCheck
  '';

  meta = {
    description = "Headless browser designed for AI and automation";
    homepage = "https://lightpanda.io";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames supportedSystems;
    mainProgram = "lightpanda";
  };
}
