{
  config,
  pkgs,
  inputs,
  ...
}:

let
  adminPort = toString config.processes.restate.ports.admin.value;

  greeter = config.tasks."devenv:restate:register-greeter";
  worker = config.tasks."devenv:restate:register-worker";
in
{
  services.restate = {
    enable = true;
    package = inputs.nix-restate.packages.${pkgs.stdenv.hostPlatform.system}.restate-bin;

    deployments = {
      greeter = {
        uri = "http://127.0.0.1:9080";
        after = [ "devenv:greeter:build" ];
      };

      worker = {
        uri = "http://127.0.0.1:8787";
        force = false;
        http1 = true;
        headers = {
          Authorization = "Bearer secret";
          X-Env = "dev";
        };
      };
    };
  };

  tasks."devenv:greeter:build".exec = "true";

  # Registration needs real service endpoints, which this fixture does not have:
  # only check the generated tasks, and skip running them.
  tasks."devenv:restate:register-greeter".status = "true";
  tasks."devenv:restate:register-worker".status = "true";

  assertions = [
    {
      assertion =
        greeter.after == [
          "devenv:processes:restate@ready"
          "devenv:greeter:build"
        ];
      message = "Registration should wait for Restate and the deployment's dependencies.";
    }
    {
      assertion = worker.after == [ "devenv:processes:restate@ready" ];
      message = "Registration should wait for Restate.";
    }
    {
      assertion =
        greeter.wantedBy == [ "devenv:processes:restate" ]
        && worker.wantedBy == [ "devenv:processes:restate" ];
      message = "Registration should run when Restate starts.";
    }
    {
      assertion = pkgs.lib.hasSuffix "/bin/restate --yes deployments register --force http://127.0.0.1:9080" greeter.exec;
      message = "Deployments should be force-registered by default: ${greeter.exec}";
    }
    {
      assertion = pkgs.lib.hasSuffix "/bin/restate --yes deployments register --use-http1.1 --extra-header 'Authorization=Bearer secret' --extra-header 'X-Env=dev' http://127.0.0.1:8787" worker.exec;
      message = "Registration flags should follow the deployment options: ${worker.exec}";
    }
    {
      assertion =
        greeter.env.RESTATE_ADMIN_URL == "http://127.0.0.1:${adminPort}"
        && greeter.env.RESTATE_ENVIRONMENT == "local";
      message = "Registration should target the managed server.";
    }
  ];
}
