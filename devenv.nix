{ pkgs, ... }:

{
  packages = [
    pkgs.git
    pkgs.jq
  ];

  outputs.docs-options = import ./docs/gen/options.nix {
    inherit pkgs;
  };

  scripts.generate-docs = {
    description = "Generate reference documentation";
    exec = "bash ./docs/gen/generate-options.sh";
  };

  scripts.test-fixtures.exec = ''
    set -euo pipefail

    repo_root="$(git rev-parse --show-toplevel)"
    tmp_root="$(mktemp -d "''${TMPDIR:-/tmp}/devenv-extras-tests.XXXXXX")"
    trap 'rm -rf "$tmp_root"' EXIT

    found=0
    for fixture in "$repo_root"/tests/*; do
      [ -d "$fixture" ] || continue
      found=1

      name="$(basename "$fixture")"
      workdir="$tmp_root/$name"

      mkdir -p "$workdir"
      cp -R "$fixture"/. "$workdir"/

      echo "==> testing $name"
      (cd "$workdir" && git init -q && devenv --override-input devenv-extras "path:$repo_root" test)
    done

    if [ "$found" -eq 0 ]; then
      echo "No test fixtures found" >&2
      exit 1
    fi
  '';

  enterTest = ''
    test-fixtures
  '';
}
