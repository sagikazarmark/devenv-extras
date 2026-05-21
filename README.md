# devenv-extras

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/sagikazarmark/devenv-extras/ci.yaml?style=flat-square)](https://github.com/sagikazarmark/devenv-extras/actions/workflows/ci.yaml)

Extra packages and modules for [devenv](https://devenv.sh/).

## Quickstart

Add `devenv-extras` to `devenv.yaml` and import its modules:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  extras:
    url: github:sagikazarmark/devenv-extras
    # Add overlays if needed
    # overlays:
    #   - default

imports:
  - extras/modules
```

Then enable the modules you need in `devenv.nix`:

```nix
{ ... }:

{
  languages.dang.enable = true;
  # dagger.enable = true;
  # services.sandbox-agent.enable = true;
}
```

## Options

See the generated option reference: [docs/reference/options.md](docs/reference/options.md).

Regenerate it after changing module options:

```sh
devenv shell -- generate-docs
```

## Testing

Run all fixture tests:

```sh
devenv test
```

Run flake checks:

```sh
nix flake check
```
