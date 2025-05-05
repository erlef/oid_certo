defmodule OIDCerto.CLI.CreatePlan do
  @moduledoc false

  @behaviour OIDCerto.CLI.Command

  import OIDCerto.CLI.Command

  alias OIDCerto.CLI.Command

  @impl Command
  def run!(%Optimus.ParseResult{options: options, args: %{plan_name: plan_name, variant: variant, config: config}}) do
    configure_application(options)

    %Req.Response{status: 201, body: plan} = OIDCerto.ApiClient.plan_create(plan_name, variant, config)

    IO.puts(plan["id"])
  end
end
