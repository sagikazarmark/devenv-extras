# A shell snippet that moves the extension library cargo built from `$out/lib` to
# `$out/lib/php/extensions/<extensionName>.so`, where nixpkgs' `php.withExtensions` looks for it.
# PHP loads extensions as `.so` on every platform, including macOS.
sharedLibrary: extensionName: ''
  shopt -s nullglob
  libraries=("$out"/lib/*${sharedLibrary})
  shopt -u nullglob

  if [ "''${#libraries[@]}" -ne 1 ]; then
    echo "expected cargo to build one ${sharedLibrary} library, found ''${#libraries[@]}: ''${libraries[*]}" >&2
    echo "Build only the extension crate, for example with buildAndTestSubdir or cargoBuildFlags." >&2
    exit 1
  fi

  install -Dm755 "''${libraries[0]}" "$out/lib/php/extensions/${extensionName}.so"
  rm "''${libraries[0]}"
''
