{ config, pkgs, ... }:

let
  writer = config.wrangler.dev.writer;
  reader = config.wrangler.dev.reader;
  migrate = config.tasks."devenv:wrangler:migrate-writer";
in
{
  packages = [
    pkgs.curl
    pkgs.jq
  ];

  # The writer migrates the database of its dev environment, which the reader uses too.
  wrangler = {
    enable = true;
    dev = {
      writer = {
        environment = "dev";
        persistTo = reader.persistTo;
        vars.SELF_URL = writer.url;
        d1.migrate = [ "DB" ];
      };
      reader = { };
    };
  };

  env = {
    WRITER_URL = writer.url;
    READER_URL = reader.url;
  };

  assertions = [
    {
      assertion = reader.persistTo == "${config.devenv.state}/wrangler/state/reader";
      message = "Each worker should keep its local data in its own directory by default.";
    }
    {
      assertion =
        config.processes.wrangler-reader.after == [ ]
        && config.processes.wrangler-writer.after == [ "devenv:processes:wrangler-reader" ];
      message = "Workers sharing a directory should start one after the other.";
    }
    {
      assertion =
        migrate.before == [
          "devenv:processes:wrangler-reader"
          "devenv:processes:wrangler-writer"
        ];
      message = "Migrations should run before every worker using the directory.";
    }
    {
      assertion =
        writer.url == "http://127.0.0.1:${toString config.processes.wrangler-writer.ports.http.value}";
      message = "The worker URL should use the allocated port.";
    }
    {
      assertion = config.processes.wrangler-writer.ready.exec != null;
      message = "Workers should have a ready probe by default.";
    }
  ];
}
