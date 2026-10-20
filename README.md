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
  # languages.tailwindcss.enable = true;
  # dagger.enable = true;
  # dioxus.enable = true;
  # worker-build.enable = true;
  # wrangler.enable = true;
  # services.litellm.enable = true;
  # services.openbao.enable = true;
  # services.restate.enable = true;
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

### Dioxus

Add the [Dioxus](https://dioxuslabs.com/) CLI (`dx`) and the tools it runs:
`wasm-bindgen-cli`, esbuild and `wasm-opt` (from binaryen). The Nix build of `dx`
does not download esbuild or `wasm-opt` itself:

```nix
dioxus.enable = true;
```

`dx` and `wasm-bindgen-cli` must match the `dioxus` and `wasm-bindgen` crates
exactly, so `dioxus.version` and `dioxus.wasm-bindgen.version` default to the
versions in `Cargo.lock` at the project root. Point `dioxus.cargoLock` at another
lockfile, for example in a workspace subdirectory. Without a lockfile, the
versions are null and `pkgs.dioxus-cli` and `pkgs.wasm-bindgen-cli` are installed.

A version comes from nixpkgs when it has it, including versioned attributes such
as `pkgs.wasm-bindgen-cli_0_2_100`. Otherwise it comes from
[nixpkgs-multiverse](https://github.com/fzakaria/nixpkgs-multiverse) through
devenv's `multiverse` argument, which needs the input:

```sh
devenv inputs add nixpkgs-multiverse github:fzakaria/nixpkgs-multiverse
```

Set `dioxus.esbuild.version` or `dioxus.wasm-opt.version` (a binaryen version) to
pin those the same way. Each tool also has a `package` option that overrides its
version, and `dioxus.wasm-bindgen.enable`, `dioxus.esbuild.enable` and
`dioxus.wasm-opt.enable` turn the extra tools off.

`dioxus.enable` also enables `languages.rust` by default; set
`languages.rust.enable = false` to use a toolchain from outside devenv. Building
for the web needs the `wasm32-unknown-unknown` target, which the default
`nixpkgs` channel cannot add, so devenv warns until the toolchain has it:

```nix
languages.rust = {
  channel = "stable";
  targets = [ "wasm32-unknown-unknown" ];
};
```

`dioxus.serve.enable` adds a `dioxus` process that runs `dx serve`, which
rebuilds and hot-reloads the app as you edit it:

```nix
dioxus = {
  enable = true;
  serve = {
    enable = true;
    # directory = "app";              # the crate, relative to the project root
    # extraArgs = [ "--hot-patch" ];
  };
};
```

The dev server listens on `127.0.0.1` at a port allocated from 8080; set
`dioxus.serve.host` and `dioxus.serve.port` to change them.
`config.processes.dioxus.ports.http.value` has the allocated port.

For HTTPS, use the [devenv proxy](https://devenv.sh/processes/), which serves the
app with a certificate from the project's mkcert certificate authority. Hot
reloading works through it, because the app connects to the dev server's
WebSocket on the page's own host, with `wss:` on HTTPS pages:

```nix
process.proxy.enable = true;

processes.dioxus.proxy = {
  hostname = "app.localhost";
  https.enable = true;
};
```

When the project has no certificate authority yet, devenv runs `mkcert -install`,
which adds it to the system trust stores so browsers accept the certificate.

`dioxus.import` builds an app with `dx bundle` as a Nix package, for devenv
[outputs](https://devenv.sh/outputs/). Dependencies are vendored from
`Cargo.lock` and `dx` uses the tools above (and the `languages.tailwindcss`
package, if enabled), so the build runs offline:

```nix
{ config, ... }:

{
  dioxus.enable = true;

  outputs.web = config.dioxus.import ./. { };
}
```

`devenv build outputs.web` then builds the bundle: the web app in `public`, and
for fullstack apps the `server` executable next to it. dx reads `Dioxus.toml` as
usual. The second argument takes:

- `platform` (default `"web"`). Other platforms need packaging tools that may
  not work in the Nix sandbox.
- `fullstack = true` builds the server even when the `fullstack` feature of
  `dioxus` is not enabled. dx always builds it when that feature is enabled,
  either on the `dioxus` dependency or through a crate feature in
  `buildFeatures`, so keep it out of those for a client-only bundle.
- `release` (default `true`).
- `buildFeatures` and `buildNoDefaultFeatures` for cargo features.
- `dxFlags`: more flags for `dx bundle`.
- `rustPlatform` to build without the devenv Rust toolchain.

Other arguments go to `rustPlatform.buildRustPackage`, such as
`buildAndTestSubdir` for a crate in a workspace subdirectory, or `buildInputs`
for libraries the server links to.

### worker-build

Add [worker-build](https://github.com/cloudflare/workers-rs), which builds Rust
Cloudflare Workers:

```nix
worker-build.enable = true;
```

`worker-build` is released together with the `worker` crate, so
`worker-build.version` defaults to the version of `worker` in `Cargo.lock`, the
same way as Dioxus: set `worker-build.cargoLock` to read another lockfile, and a
version missing from nixpkgs comes from nixpkgs-multiverse. Without a lockfile,
`pkgs.worker-build` is installed. `worker-build.package` overrides the version.

Like Dioxus, `worker-build.enable` enables `languages.rust` by default and
warns until the toolchain has the `wasm32-unknown-unknown` target.

`worker-build.import` builds a worker the same way as `dioxus.import`, and
returns the contents of worker-build's `build` directory:

```nix
outputs.worker = config.worker-build.import ./. { };
```

worker-build would download wasm-bindgen, esbuild and `wasm-opt`, so the build
points it at `worker-build.wasm-bindgen.package` (matching `wasm-bindgen` in
`Cargo.lock`), `worker-build.esbuild.package` and `worker-build.wasm-opt.package`
instead. The second argument takes `release` (default `true`; `false` builds
with `--dev`), `buildFeatures`, `buildNoDefaultFeatures`, `rustPlatform`, and
`workerBuildFlags` for more worker-build flags. Other arguments go to
`rustPlatform.buildRustPackage`.

### Wrangler

Add [Wrangler](https://developers.cloudflare.com/workers/wrangler/), and run
workers locally with `wrangler dev`:

```nix
wrangler = {
  enable = true;
  dev = {
    api = { };                          # the worker in ./api
    app.directory = "workers/app";
  };
};
```

Each worker runs in its own `wrangler-<name>` process, with `wrangler --cwd`
set to its directory, so its configuration and custom build (such as
`worker-build`) work unchanged. Ports are allocated from 8787 for HTTP and 9229
for the inspector, counting up in the order of the workers; set `port` and
`inspectorPort` to change them, `config` for a configuration file other than
`wrangler.toml`, `wrangler.json` or `wrangler.jsonc`, and `extraArgs` for more
`wrangler dev` flags.

The sessions reach each other through Wrangler's dev registry: a worker can call
another through a service binding, or use a Durable Object defined in another
with `script_name`. The registry is in the devenv state directory, so workers of
other projects stay apart; `WRANGLER_REGISTRY_PATH` points to it in the shell as
well, and `wrangler.registry = null` uses Wrangler's global one.

With `worker-build.enable`, the processes point worker-build at esbuild and
`wasm-opt` from Nix, and at wasm-bindgen too when its version is known from
`Cargo.lock`, instead of downloading them.

For HTTPS, use the [devenv proxy](https://devenv.sh/processes/) the same way as
for Dioxus. Without a `hostname`, a worker's URL is
`wrangler-<name>.<project>.localhost`, after its process; its inspector gets
`inspector.` in front of that:

```nix
process.proxy.enable = true;

processes.wrangler-app.proxy = {
  hostname = "app.localhost";
  https.enable = true;
};
```

The proxy terminates TLS: `wrangler dev` still receives HTTP, and devenv adds
`X-Forwarded-Proto: https` to HTTPS requests.

### Tailwind CSS

Add the Tailwind CSS CLI and its language server:

```nix
languages.tailwindcss.enable = true;
```

The CLI defaults to `pkgs.tailwindcss_4`; override `languages.tailwindcss.package`
to use a different version. Disable the language server with
`languages.tailwindcss.lsp.enable = false`, or choose another one with
`languages.tailwindcss.lsp.package`.

### LiteLLM

Run a [LiteLLM](https://docs.litellm.ai/) proxy with `devenv up`:

```nix
services.litellm = {
  enable = true;
  settings.model_list = [
    {
      model_name = "claude-sonnet";
      litellm_params = {
        model = "anthropic/claude-sonnet-4-5";
        api_key = "os.environ/ANTHROPIC_API_KEY";
      };
    }
  ];
};
```

`services.litellm.settings` is rendered to the proxy's
[config file](https://docs.litellm.ai/docs/proxy/configs). The server port is
allocated from `services.litellm.port` (default `4000`). The shell exports
`LITELLM_PROXY_URL` (read by the `litellm-proxy` CLI) and `LITELLM_PROXY_API_BASE`
(read by the LiteLLM SDK for `litellm_proxy/` models) pointing at the managed
server. Telemetry is disabled by default.

When devenv's [Ollama service](https://devenv.sh/services/ollama/) is enabled as
well, LiteLLM routes `ollama/<model>` to the managed Ollama server and starts after
Ollama is ready:

```nix
services.ollama = {
  enable = true;
  loadModels = [ "gemma3" ];
};

services.litellm.enable = true;
```

Models in `services.ollama.loadModels` are listed explicitly so clients discover
them through `/v1/models`; any other pulled model is reachable through a wildcard
route. Change the prefix with `services.litellm.ollama.prefix`, the listed models
with `services.litellm.ollama.models`, or disable the integration with
`services.litellm.ollama.enable = false`.

devenv-extras used to provide `services.ollama`; it moved to devenv with the same
options. If the option is missing, update devenv's modules with `devenv update`.

### OpenBao

Run an [OpenBao](https://openbao.org/) server with `devenv up`:

```nix
services.openbao.enable = true;
```

Unlike `bao server -dev`, the server keeps its data across restarts. On the first
start, it initializes itself with
[self-initialization](https://openbao.org/docs/configuration/self-init/) and
unseals itself on every start with a
[static seal](https://openbao.org/docs/configuration/seal/static/) key, generated
in `.devenv/state/openbao/unseal.key`. There are no unseal keys or root token to
copy: self-initialization creates a token with the root policy and the ID from
`services.openbao.token` (default `root`), and mounts a KV version 2 secrets engine
at `secret/`, like the development server.

The API port is allocated from `services.openbao.port` (default `8200`), and the
cluster listener, which OpenBao always starts, from `services.openbao.clusterPort`
(default `8201`). The shell exports `BAO_ADDR` and `BAO_TOKEN`, so `bao` works
without extra configuration:

```sh
bao kv put secret/app api_key=secret
```

It also exports `VAULT_ADDR` and `VAULT_TOKEN` for clients that only support
Vault, such as Terraform. Disable them with `services.openbao.exportVaultEnv = false`.
The web UI is served at `$BAO_ADDR/ui`.

Add your own requests to run during self-initialization, such as enabling auth
methods or writing secrets. Requests can read the server's environment, set with
`services.openbao.environmentVariables`:

```nix
services.openbao = {
  enable = true;
  environmentVariables.ADMIN_PASSWORD = "admin";
  initialize = [
    {
      name = "userpass";
      requests = [
        {
          name = "enable-userpass";
          operation = "update";
          path = "sys/auth/userpass";
          data.type = "userpass";
        }
        {
          name = "add-admin";
          operation = "update";
          path = "auth/userpass/users/admin";
          data = {
            password = {
              eval_source = "env";
              eval_type = "string";
              env_var = "ADMIN_PASSWORD";
            };
            token_policies = [ "root" ];
          };
        }
      ];
    }
  ];
};
```

Self-initialization only runs against empty storage, so changes to `token`, `kv`
or `initialize` apply only after removing the data directory. Devenv prints a
warning with the directory to remove when they change.

Data is stored with the `pebbledb` backend on OpenBao 2.7 and later, which removed
the `file` backend, and with `file` before. Each backend has its own directory
under `.devenv/state/openbao`. Set `services.openbao.storage.backend = "raft"` to
use integrated storage instead; its first start takes several seconds. Use
`services.openbao.settings` for any other
[server configuration](https://openbao.org/docs/configuration/), such as
`log_level`.

The server listens on plain HTTP. For HTTPS, use the
[devenv proxy](https://devenv.sh/processes/), which serves OpenBao with a
certificate from the project's mkcert certificate authority. The client variables
are defaults, so pointing them at the proxy is a plain override:

```nix
process.proxy.enable = true;

processes.openbao.proxy = {
  hostname = "openbao.localhost";
  https.enable = true;
};

# Optional: point clients at the proxy instead of the direct port.
env.BAO_ADDR = "https://openbao.localhost";
```

`VAULT_ADDR` and `VAULT_TOKEN` follow `BAO_ADDR` and `BAO_TOKEN`. If the
certificate authority is not trusted by the system, also set
`env.BAO_CACERT = "${config.env.DEVENV_STATE}/mkcert/rootCA.pem"`.

### Restate

Run a [Restate](https://restate.dev/) server with `devenv up`.

Restate is unfree, and nixpkgs builds it from source, which takes a long time.
[nix-restate](https://github.com/sagikazarmark/nix-restate) packages the official
release binaries as `restate-bin`. Add it to `devenv.yaml`:

```yaml
inputs:
  nix-restate:
    url: github:sagikazarmark/nix-restate
    inputs:
      nixpkgs:
        follows: nixpkgs
```

Then enable the service with that package:

```nix
{ pkgs, inputs, ... }:

{
  services.restate = {
    enable = true;
    package = inputs.nix-restate.packages.${pkgs.stdenv.hostPlatform.system}.restate-bin;
  };
}
```

The default, `pkgs.restate`, requires `nixpkgs.allow_unfree: true` (or
`nixpkgs.permitted_unfree_packages: [ restate ]`) in `devenv.yaml`.

The ingress port is allocated from `services.restate.port` (default `8080`), the
admin API from `services.restate.adminPort` (default `9070`) and node-to-node
communication from `services.restate.nodePort` (default `5122`). The shell exports
`RESTATE_ADMIN_URL`, `RESTATE_INGRESS_URL` and `RESTATECTL_ADDRESS`, so `restate`
and `restatectl` work without extra configuration. It also sets
`RESTATE_ENVIRONMENT=local`, so that a CLI environment selected in
`~/.config/restate`, such as a Restate Cloud one, does not apply to the managed
server. The web UI is served at `$RESTATE_ADMIN_URL/ui`.

Data is stored in `.devenv/state/restate`, under a fixed node name
(`services.restate.nodeName`, default `devenv`): Restate defaults to the hostname,
and the node's data becomes unusable when it changes. The server listens on TCP only, because
Unix sockets created under the data directory easily exceed the socket path length
limit. Telemetry is disabled, and the server provisions 4 partitions with 512 MiB
of RocksDB memory instead of the production defaults. Use
`services.restate.settings` for any other
[server configuration](https://docs.restate.dev/references/server-config):

```nix
services.restate.settings = {
  default-journal-retention = "7d";
  worker.invoker.inactivity-timeout = "5m";
};
```

Partitions are only provisioned on the first start: remove the data directory to
change them.

Register service deployments once Restate and the processes serving them are ready:

```nix
{ config, ... }:

{
  processes.greeter = {
    exec = "npm run dev";
    ports.http.allocate = 9080;
    env.PORT = toString config.processes.greeter.ports.http.value;
  };

  services.restate.deployments.greeter = {
    uri = "http://127.0.0.1:${toString config.processes.greeter.ports.http.value}";
    after = [ "devenv:processes:greeter" ];
  };
}
```

Each deployment is registered by a `devenv:restate:register-<name>` task with
`restate deployments register`, replacing an earlier registration of the same
endpoint (disable with `force = false`). A process in `after` needs a
[ready probe](https://devenv.sh/processes/#ready-probes) or allocated ports.
Registration runs when Restate starts: after changing services, register them
again with `restate deployments register --force <uri>`. Before devenv 2.3.2,
`devenv up` skips tasks that run after a process: use `devenv up --mode all`.
Set `http1 = true` for endpoints that only support HTTP/1.1, such as `wrangler dev`.

The client variables are defaults, so you can point them at the
[devenv proxy](https://devenv.sh/processes/), like with OpenBao.

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
