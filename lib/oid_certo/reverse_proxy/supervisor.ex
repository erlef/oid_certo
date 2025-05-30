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
        {LocalhostRun, internal_port: 34_789, ssh_options: ssh_options(), connect_timeout: to_timeout(minute: 1)}
      ],
      strategy: :one_for_one
    )
  end

  @spec ssh_options() :: :ssh.client_options()
  defp ssh_options do
    case System.fetch_env("SSH_AUTH_SOCK") do
      :error -> [user: ~c"nokey"]
      {:ok, _sock} -> [user: ~c"any", key_cb: {:ssh_agent, []}]
    end
  end
end
