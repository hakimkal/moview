defmodule Moview.Movies.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Moview.Movies.Worker.start_link(arg1, arg2, arg3)
      # worker(Moview.Movies.Worker, [arg1, arg2, arg3]),
      supervisor(Moview.Movies.Repo, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Moview.Movies.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
