{
  imports = [
    ./languages/dang
    ./languages/tailwindcss
    ./integrations/dagger.nix
    ./integrations/vale.nix
    ./services/litellm.nix
    ./services/ollama.nix
    ./services/sandbox-agent.nix
  ];
}
