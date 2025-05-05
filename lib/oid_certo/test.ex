defmodule OIDCerto.Test do
  @moduledoc false

  import ExUnit.Assertions

  alias ExUnit.Callbacks
  alias OIDCerto.ApiClient
  alias OIDCerto.Implementation
  alias OIDCerto.Test.Plan

  require Logger

  def define_with_test(plan, test_name) do
    define(
      plan,
      [
        %{
          certification_plan_name: plan["planName"],
          certification_test_name: test_name
        }
      ]
    )
  end

  def define_with_plan(plan, opts \\ []) do
    %{"modules" => modules} = plan

    ignore = opts[:ignore] || []

    define(
      plan,
      for %{"testModule" => test_name} <- modules,
          test_name not in ignore do
        %{
          certification_plan_name: plan["planName"],
          certification_test_name: test_name
        }
      end
    )
  end

  defp define(plan, parameters) do
    %{"planName" => plan_name} = plan

    internal_id = :erlang.phash2({plan, parameters})
    internal_id = Base.url_encode64(<<internal_id::64>>, padding: false)

    module_name = Module.concat([__MODULE__, plan_name |> String.replace("-", "_") |> Macro.camelize(), internal_id])

    defmodule module_name do
      use ExUnit.Case,
        parameterize: Enum.map(parameters, &Map.put(&1, :internal_id, internal_id)),
        async: true

      alias OIDCerto.Test

      @moduletag certification_plan: plan
      @moduletag internal_id: internal_id

      setup {Test, :setup_logger}
      setup {Test, :setup_output}
      setup {Test, :setup_test}
      setup {Test, :setup_wallaby}
      setup {Test, :setup_implementation}

      @tag :tmp_dir
      test "run test", tags do
        assert :ok = Test.test(tags)
      end
    end
  end

  @doc false
  def setup_output(tags) do
    {dir, delete?} =
      case Application.get_env(:oid_certo, :output_directory) do
        nil ->
          {tags.tmp_dir, true}

        dir ->
          {Path.join([dir, tags.certification_plan["planName"], tags.internal_id, tags.certification_test_name]), false}
      end

    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    Callbacks.on_exit(fn ->
      if delete? do
        File.rm_rf!(dir)
      end
    end)

    {:ok, output_directory: dir}
  end

  @doc false
  def setup_wallaby(_tags) do
    screenshot_dir = Path.join(System.tmp_dir!(), "wallaby_screenshots")
    Application.put_env(:wallaby, :screenshot_dir, screenshot_dir)

    {:ok, wallaby_session} =
      Wallaby.start_session(
        capabilities: %{
          chromeOptions: %{
            args: [
              "--headless",
              "--no-sandbox",
              "window-size=1280,800",
              "--fullscreen",
              "--disable-gpu",
              "--disable-dev-shm-usage"
            ]
          }
        }
      )

    Callbacks.on_exit(fn ->
      assert :ok = Wallaby.end_session(wallaby_session)

      :ok
    end)

    {:ok, wallaby_session: wallaby_session, wallaby_screenshot_dir: screenshot_dir}
  end

  @doc false
  def setup_implementation(tags) do
    {:ok, implementation} = Implementation.start(tags.output_directory)

    Callbacks.on_exit(fn ->
      Implementation.shutdown(implementation)

      :ok
    end)

    {:ok, implementation: implementation}
  end

  @doc false
  def setup_logger(tags) do
    Logger.metadata(
      plan: tags.certification_plan["planName"],
      test: tags.certification_test_name,
      internal_id: tags.internal_id
    )

    :ok
  end

  @doc false
  def setup_test(tags) do
    test = create_test(tags.certification_plan["_id"], tags.certification_test_name)

    Logger.metadata(plan_id: tags.certification_plan["_id"], test_id: test["id"])

    Callbacks.on_exit(fn ->
      assert :ok = persist_logs(test["id"], tags.output_directory)

      :ok
    end)

    {:ok, %{certification_test: test}}
  end

  @doc false
  def test(tags) do
    Logger.info("Test Out Dir: #{inspect(tags.output_directory)}")

    test_runner = start_test(tags.certification_test["id"])

    Plan.run(
      plan: tags.certification_plan,
      test: tags.certification_test,
      test_runner: test_runner,
      wallaby_session: tags.wallaby_session,
      wallaby_screenshot_dir: tags.wallaby_screenshot_dir,
      implementation: tags.implementation,
      output_directory: tags.output_directory
    )

    assert :ok = wait_for_test_status(tags.certification_test["id"], "FINISHED")
  end

  defp create_test(plan_id, test_name) do
    %Req.Response{status: 201, body: body} =
      ApiClient.test_create(plan_id, test_name)

    body
  end

  defp start_test(test_id) do
    :ok = wait_for_test_status(test_id, "WAITING")

    %Req.Response{status: 200, body: body} =
      ApiClient.test_start(test_id)

    body
  end

  defp wait_for_test_status(test_id, status, threshold \\ 10) do
    case ApiClient.test_info(test_id) do
      %Req.Response{status: 200, body: %{"status" => ^status}} ->
        :ok

      %Req.Response{status: 200, body: %{"status" => "INTERRUPTED"}} ->
        Logger.error("Test was interrupted")
        {:error, :interrupted}

      %Req.Response{status: 200, body: %{}} when threshold > 0 ->
        Process.sleep(500)
        wait_for_test_status(test_id, status, threshold - 1)

      %Req.Response{status: 200, body: %{"status" => current_status}} when threshold == 0 ->
        Logger.error("Test status is #{inspect(current_status)}, expected #{inspect(status)}")
        {:error, :timeout}
    end
  end

  defp persist_logs(test_id, output_directory) do
    %Req.Response{status: 200, body: logs_html_zip} = ApiClient.test_logs_html(test_id)

    {:ok, _out} =
      :zip.unzip(
        logs_html_zip,
        cwd: String.to_charlist(output_directory)
      )

    :ok
  end
end
