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

Dang works without an overlay: it uses `pkgs.dang` when available and otherwise
builds the bundled package. Override `languages.dang.package` to choose a different
package explicitly.

If you only need modules that do not require an overlay, you can also add
`flake: false` to the `extras` input.

## Options

### Vale

Enable Vale, its language server, and the built-in git hook:

The hook uses devenv's `git-hooks` input. If it is not already configured, add
`git-hooks` with URL `github:cachix/git-hooks.nix` to `devenv.yaml` inputs.

```nix
vale.enable = true;
```

Without settings, `vale.config.file` defaults to `null` for discovery. When both
are null, devenv seeds `.vale.ini` with the quickstart's Microsoft and Vale styles
for Markdown, omitting `StylesPath` to use the devenv-local default. This uses
`files.".vale.ini".copyMode = "seed"`: existing regular files and later edits are
preserved. Devenv's seed mode replaces Nix-store symlinks with writable files.
The seed destination does not set `VALE_CONFIG_PATH`; Vale still discovers its
configuration, though a new `.vale.ini` can shadow a parent-directory config.

Set `vale.config.file = "docs/.vale.ini"` to select an
existing file explicitly without seeding or changing it. Selected paths are exported as absolute
`VALE_CONFIG_PATH` values, including when generated files use symlink mode.

Automatic style downloads are opt-in: set `vale.sync.enable = true` to run
`vale sync` on shell entry. Like devenv's `uv.sync` and JavaScript install
options, this defaults to false. Run `vale sync` manually or enable it before
linting with the starter's Microsoft rules.

To manage the configuration in Nix instead:

```nix
vale = {
  enable = true;
  sync.enable = true;
  config.settings = {
    globalSection = {
      MinAlertLevel = "suggestion";
      Packages = [ "Microsoft" ];
    };
    sections."*.md".BasedOnStyles = [ "Vale" "Microsoft" ];
  };
};
```

Explicit settings use `copy` mode: devenv overwrites the writable file on each
shell entry and adds a generated-file header. The filename defaults to `.vale.ini`
when settings are supplied. Commit the generated output and
check for drift in CI with `devenv shell -- true && git diff --exit-code .vale.ini`.
`vale.config.copyMode` chooses `copy` (default) or `symlink`; it only
affects generated settings. File selection, settings, and materialization are
grouped under `vale.config`. The `copyMode` name matches devenv's
`files.<name>.copyMode` API; `seed` is reserved for the automatic starter rather
than declarative settings.

Settings accept both strings and nonempty lists. Lists are rendered as
comma-separated values, so `[ "Vale" "Microsoft" ]` and `"Vale, Microsoft"`
produce the same INI value.

#### Downloaded and custom styles

`vale.stylesPath` defaults to `"${config.devenv.state}/vale/styles"`. Devenv creates
that directory and exports its absolute path as `VALE_STYLES_PATH`. **An INI
`StylesPath` takes precedence**, including for downloads: omit it to use this
devenv-local directory. Outside devenv, the same config uses Vale's normal
user-level styles directory. Contributors can install Vale and run `vale sync`.

Keep custom rules and vocabularies in a local Vale package, for example:

```text
vale-local/
└── styles/
    ├── House/
    │   └── Terms.yml
    └── config/vocabularies/Project/
        └── accept.txt
```

Add it alongside remote packages and select its styles:

```nix
vale.config.settings = {
  globalSection = {
    Packages = [ "Microsoft" "./vale-local" ];
    Vocab = "Project";
  };
  sections."*.md".BasedOnStyles = [ "Vale" "Microsoft" "House" ];
};
```

Sync copies both sources into the writable styles directory, preserving the
committed originals. Run `vale sync` again after editing custom resources.
Relative package paths are resolved from the working directory; the shell-entry
sync task runs from the devenv root. Use distinct style names to avoid collisions.
See [the source-backed research](docs/research/vale-paths.md) for path precedence
and why multiple search paths or symlink trees are not equivalent to this layout.

Disable the language server with
`vale.lsp.enable = false`, or the hook with `git-hooks.hooks.vale.enable = false`.

### Reference

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
