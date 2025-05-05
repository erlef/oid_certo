defmodule OIDCerto.CLI do
  @moduledoc false
  @app Mix.Project.config()[:app]
  @description Mix.Project.config()[:description]
  @version Mix.Project.config()[:version]

  @subcommands %{
    [:create_plan] => OIDCerto.CLI.CreatePlan,
    [:execute_plan] => OIDCerto.CLI.ExecutePlan,
    [:execute_test] => OIDCerto.CLI.ExecuteTest,
    [:cleanup_plans] => OIDCerto.CLI.CleanupPlans
  }

  @spec parse!([String.t()]) :: Optimus.ParseResult.t() | {Optimus.subcommand_path(), Optimus.ParseResult.t()}
  case Mix.env() do
    :test ->
      def parse!(argv) do
        cli_definition()
        |> Optimus.new!()
        |> Optimus.parse!(argv, &raise("Exit: #{&1}"))
      end

    _other ->
      def parse!(argv) do
        cli_definition()
        |> Optimus.new!()
        |> Optimus.parse!(argv)
      end
  end

  def run!(argv) do
    case parse!(argv) do
      {subcommand, parse_result} -> Map.fetch!(@subcommands, subcommand).run!(parse_result)
      parse_result -> OIDCerto.CLI.Main.run!(parse_result)
    end
  end

  @spec cli_definition :: Optimus.spec()
  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  defp cli_definition do
    shared_options = [
      api_base_url: [
        type: :string,
        short: "-a",
        long: "--api-base-url",
        description: "Base URL for the Conformance API",
        default: System.get_env("API_BASE_URL", "https://www.certification.openid.net")
      ],
      api_token:
        optimus_options_with_fun_default(fn -> System.fetch_env("API_TOKEN") end,
          type: :string,
          short: "-t",
          long: "--api-token",
          description: "API token for the Conformance API"
        )
    ]

    implementation_options = [
      implementation: [
        type: :string,
        short: "-i",
        long: "--implementation",
        description: "Implementation name",
        required: true,
        parser: &parse_file/1
      ]
    ]

    out_options = [
      output_directory: [
        type: :string,
        short: "-o",
        long: "--output-directory",
        description: "Directory to store output files",
        parser: &parse_directory/1
      ]
    ]

    [
      name: Atom.to_string(@app),
      description: @description,
      version: @version,
      author: "Erlang Ecosystem Foundation",
      about: "Run OpenID Conformance Tests according to the [CONFIG_FILE]",
      allow_unknown_args: false,
      parse_double_dash: true,
      allow_unknown_args: false,
      args: [
        config_file: [
          type: :string,
          short: "-c",
          long: "--config-file",
          description: "Path to the configuration file",
          required: true,
          parser: &parse_file/1
        ]
      ],
      options: shared_options ++ implementation_options ++ out_options,
      subcommands: [
        create_plan: [
          name: "create-plan",
          about: "Creates a plan",
          args: [
            plan_name: [
              type: :string,
              description: "Name of the plan to use",
              required: true
            ],
            variant: [
              type: :string,
              description: "Variant Config, either a Path or a JSON string",
              required: true,
              parser: &parse_json_config/1
            ],
            config: [
              type: :string,
              description: "Configuration for the plan",
              required: true,
              parser: &parse_json_config/1
            ]
          ],
          options: shared_options
        ],
        execute_plan: [
          name: "execute-plan",
          about: "Executes a full plan",
          args: [
            plan_id: [
              type: :string,
              description: "ID of the plan to execute",
              required: true
            ]
          ],
          options: shared_options ++ implementation_options ++ out_options
        ],
        execute_test: [
          name: "execute-test",
          about: "Executes a singular test",
          args: [
            plan_id: [
              type: :string,
              description: "ID of the plan to execute",
              required: true
            ],
            test_name: [
              type: :string,
              description: "Name of the test to execute",
              required: true
            ]
          ],
          options: shared_options ++ implementation_options ++ out_options
        ],
        cleanup_plans: [
          name: "cleanup-plans",
          about: "Purges all unpublished plans by the account of the token",
          options: shared_options
        ]
      ]
    ]
  end

  @spec optimus_options_with_fun_default(
          fetch_fun :: (-> {:ok, value} | :error),
          details :: Keyword.t()
        ) :: Keyword.t()
        when value: term()
  defp optimus_options_with_fun_default(fetch_fun, details) when is_function(fetch_fun, 0) do
    case fetch_fun.() do
      {:ok, value} -> [default: value]
      :error -> [required: true]
    end ++ details
  end

  @spec parse_file(Path.t()) :: Optimus.parser_result()
  defp parse_file(path) do
    path =
      case System.find_executable(path) do
        nil -> Path.expand(path, File.cwd!())
        path -> path
      end

    if File.regular?(path) do
      {:ok, path}
    else
      {:error, "File is not a regular file: #{path}"}
    end
  end

  @spec parse_directory(Path.t()) :: Optimus.parser_result()
  defp parse_directory(path) do
    path = Path.expand(path, File.cwd!())

    if File.dir?(path) do
      {:ok, path}
    else
      {:error, "File is not a directory: #{path}"}
    end
  end

  @spec parse_json_config(String.t()) :: Optimus.parser_result()
  defp parse_json_config(config) do
    if File.regular?(config) do
      config
      |> File.read!()
      |> parse_json_config()
    else
      Jason.decode(config)
    end
  end
end
