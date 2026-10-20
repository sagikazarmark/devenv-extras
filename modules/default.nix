{
  imports = [
    ./languages/dang
    ./languages/tailwindcss
    ./integrations/dagger.nix
    ./integrations/dioxus.nix
    ./integrations/vale.nix
    ./integrations/worker-build.nix
    ./integrations/wrangler.nix
    ./services/litellm.nix
    ./services/ollama.nix
    ./services/openbao.nix
    ./services/restate.nix
    ./services/sandbox-agent.nix
  ];
}
