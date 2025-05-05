case Mix.env() do
  :prod ->
    :ignore

  _env ->
    defmodule Mix.Tasks.OidCerto do
      @shortdoc "Run the OpenID Conformance CLI"
      @moduledoc @shortdoc

      use Mix.Task

      alias OIDCerto.CLI

      @requirements ["app.start"]

      @impl Mix.Task
      def run(args), do: CLI.run!(args)
    end
end
