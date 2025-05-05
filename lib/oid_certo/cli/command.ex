defmodule OIDCerto.CLI.Command do
  @moduledoc false

  alias OIDCerto.ApiClient

  @callback run!(Optimus.ParseResult.t()) :: :ok | no_return()

  def run_ex_unit do
    ExUnit.configure(autorun: false, capture_log: true, max_cases: System.schedulers_online())
    ExUnit.run()
  end

  def configure_application(%{api_token: token, api_base_url: base_url}) do
    Application.put_env(:oid_certo, ApiClient, token: token, base_url: base_url)
  end

  def configure_implementation(%{implementation: implementation}) do
    Application.put_env(:oid_certo, OIDCerto.Implementation, executable: implementation)
  end

  def configure_output_directory(options)

  def configure_output_directory(%{output_directory: output_directory}) do
    Application.put_env(:oid_certo, :output_directory, output_directory)
  end

  def configure_output_directory(_options), do: :ok

  def start_reverse_proxy do
    {:ok, _pid} = Supervisor.start_link([OIDCerto.ReverseProxy.Supervisor], strategy: :one_for_one)

    :ok
  end
end
