defmodule OIDCerto.Application do
  @moduledoc false

  use Application

  alias Burrito.Util.Args
  alias OIDCerto.CLI

  @impl Application
  def start(_type, _args) do
    if Burrito.Util.running_standalone?() do
      CLI.run!(Args.argv())

      System.stop(0)
    end

    Supervisor.start_link([], strategy: :one_for_one, name: OIDCerto.Supervisor)
  end
end
