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
    while IFS= read -r config; do
      fixture="''${config%/devenv.nix}"
      name="''${fixture#"$repo_root/tests/"}"
      found=1

      workdir="$tmp_root/$name"

      mkdir -p "$workdir"
      cp -R "$fixture"/. "$workdir"/

      cat > "$workdir/devenv.yaml" <<'EOF'
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  devenv-extras:
    url: github:sagikazarmark/devenv-extras
    overlays:
      - dang
      - sandbox-agent

imports:
  - devenv-extras/modules

strict_ports: true
EOF

      echo "==> testing $name"
      (cd "$workdir" && git init -q && devenv --override-input devenv-extras "path:$repo_root" test)
    done < <(find "$repo_root/tests" -path "*/.devenv/*" -prune -o -name devenv.nix -type f -print | LC_ALL=C sort)

    if [ "$found" -eq 0 ]; then
      echo "No test fixtures found" >&2
      exit 1
    fi
  '';

  enterTest = ''
    test-fixtures
  '';
}
