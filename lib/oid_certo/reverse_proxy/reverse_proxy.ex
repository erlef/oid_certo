defmodule OIDCerto.ReverseProxy.Plug do
  @moduledoc false
  @behaviour Plug

  import Plug.Conn

  alias Plug.Conn

  @impl Plug
  def init(opts) do
    opts |> Keyword.validate!([:implementation_registry]) |> Map.new()
  end

  @impl Plug
  def call(conn, opts)

  def call(%Conn{path_info: [implementation_name | rest]} = conn, %{implementation_registry: implementation_registry}) do
    case Registry.lookup(implementation_registry, implementation_name) do
      [{_pid, port}] ->
        reverse_proxy(%{conn | path_info: rest}, port)

      [] ->
        send_resp(conn, :service_unavailable, "No test implementation available")
    end
  end

  def call(conn, _opts) do
    send_resp(conn, :not_found, "No test implementation specified")
  end

  defp reverse_proxy(conn, port) do
    opts =
      ReverseProxyPlug.init(
        upstream: "http://localhost:#{port}",
        client: ReverseProxyPlug.HTTPClient.Adapters.Req,
        client_options: [redirect: false]
      )

    ReverseProxyPlug.call(conn, opts)
  end
end
