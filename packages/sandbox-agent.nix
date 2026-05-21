{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.4.2";
  baseUrl = "https://releases.rivet.dev/sandbox-agent/${version}/binaries";

  supportedSystems = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-KvO8MwhxgSRTwKVBqqBy+WGj8yEWdbuGXPhYXdjVNb0=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-nitW/yTXIbJXcytzKO2B3vpBGJ79OjcB3OwMhepXsVE=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-urCYq++HSt5IGqe1BGNmKBT78nKUOZ9UUwf+22OPAps=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-UDYfh7mmznS6yvB/2Pd4ZiiL7oj8Rv0WIvgvYrj53Fo=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  systemInfo =
    supportedSystems.${system}
      or (throw "sandbox-agent ${version} is not packaged for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "sandbox-agent";
  inherit version;

  src = fetchurl {
    url = "${baseUrl}/sandbox-agent-${systemInfo.target}";
    hash = systemInfo.hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    if [ ! -f "$src" ]; then
      echo "Unable to find sandbox-agent source file" >&2
      exit 1
    fi

    install -D -m 0755 "$src" "$out/bin/sandbox-agent"

    runHook postInstall
  '';

  meta = {
    description = "Run Coding Agents in Sandboxes. Control Them Over HTTP.";
    homepage = "https://sandboxagent.dev";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames supportedSystems;
    mainProgram = "sandbox-agent";
  };
}
