defmodule Blockchain.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    port = Application.get_env(:blockchain, :cowboy_port, 4001)
    Logger.info "Starting webserver at port #{port}"

    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Blockchain.Worker.start_link(arg)
      # {Blockchain.Worker, arg},
      {Blockchain.Instance, nil},

      Plug.Adapters.Cowboy.child_spec(:http, Blockchain.WebServer, [], [port: port])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Blockchain.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
