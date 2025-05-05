defmodule OIDCerto.CLI.Main do
  @moduledoc false

  @behaviour OIDCerto.CLI.Command

  import OIDCerto.CLI.Command

  alias OIDCerto.ApiClient
  alias OIDCerto.Test

  @impl OIDCerto.CLI.Command
  def run!(%Optimus.ParseResult{args: %{config_file: config_file}, options: options}) do
    configure_application(options)
    configure_implementation(options)
    configure_output_directory(options)
    start_reverse_proxy()

    %{"plans" => plans} = config_file |> File.read!() |> JSON.decode!()

    for plan <- plans do
      %Req.Response{status: 201, body: created_plan} =
        ApiClient.plan_create(plan["name"], plan["variant"], plan["config"])

      %Req.Response{status: 200, body: plan_info} = ApiClient.plan_info(created_plan["id"])

      Test.define_with_plan(plan_info,
        ignore: plan["ignore"] || []
      )
    end

    run_ex_unit()

    :ok
  end
end
