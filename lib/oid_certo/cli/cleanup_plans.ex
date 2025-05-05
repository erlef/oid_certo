defmodule OIDCerto.CLI.CleanupPlans do
  @moduledoc false

  @behaviour OIDCerto.CLI.Command

  import OIDCerto.CLI.Command

  alias OIDCerto.ApiClient
  alias OIDCerto.CLI.Command

  require Logger

  @impl Command
  def run!(%Optimus.ParseResult{options: options, args: %{}}) do
    configure_application(options)

    %Req.Response{status: 200, body: %{"data" => plans}} = ApiClient.plans_list(length: 25)

    for plan <- plans, plan["publish"] == nil do
      %Req.Response{status: 204} = ApiClient.plan_delete(plan["_id"])
      Logger.info("Deleted plan #{plan["_id"]}")
    end

    :ok
  end
end
