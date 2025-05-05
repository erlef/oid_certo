defmodule OIDCerto.ReverseProxy.Supervisor do
  @moduledoc false

  use Supervisor

  alias OIDCerto.ReverseProxy.ImplementationRegistry
  alias OIDCerto.ReverseProxy.Plug

  @default_name __MODULE__

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, @default_name))
  end

  @impl Supervisor
  def init(_opts) do
    Supervisor.init(
      [
        {Registry, keys: :unique, name: ImplementationRegistry},
        {Bandit,
         plug: {Plug, implementation_registry: ImplementationRegistry},
         scheme: :http,
         port: 34_789,
         ip: :loopback,
         otp_app: :oid_certo},
        {LocalhostRun,
         internal_port: 34_789,
         ssh_options: [user: ~c"any", key_cb: {:ssh_agent, []}],
         connect_timeout: to_timeout(minute: 1)}
      ],
      strategy: :one_for_one
    )
  end
end
