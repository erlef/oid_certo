defmodule OIDCerto.CLI.ExecuteTest do
  @moduledoc false

  @behaviour OIDCerto.CLI.Command

  import OIDCerto.CLI.Command

  alias OIDCerto.ApiClient
  alias OIDCerto.CLI.Command
  alias OIDCerto.Test

  @impl Command
  def run!(%Optimus.ParseResult{options: options, args: %{plan_id: plan_id, test_name: test_name}}) do
    configure_application(options)
    configure_implementation(options)
    configure_output_directory(options)
    start_reverse_proxy()

    %Req.Response{status: 200, body: plan} = ApiClient.plan_info(plan_id)

    Test.define_with_test(plan, test_name)

    run_ex_unit()

    :ok
  end
end
