defmodule OIDCerto.Test.Plan do
  @moduledoc false
  import ExUnit.Assertions

  alias OIDCerto.ApiClient
  alias OIDCerto.Implementation
  alias OIDCerto.ReverseProxy.ImplementationRegistry

  defstruct url: nil, client_config: nil

  @login_success ~w[send_init register_client start_server open_browser trigger_login check_logged_in]a

  @login_failure ~w[send_init register_client start_server open_browser trigger_login check_login_error]a

  # styler:sort
  @test_types %{
    "oidcc-client-test" => @login_success,
    "oidcc-client-test-3rd-party-init-login" =>
      ~w[send_init register_client start_server third_party_login check_logged_in]a,
    "oidcc-client-test-aggregated-claims" => @login_success,
    "oidcc-client-test-client-secret-basic" => @login_success,
    "oidcc-client-test-discovery-issuer-mismatch" => ~w[init_failure]a,
    "oidcc-client-test-discovery-jwks-uri-keys" => ~w[send_init]a,
    "oidcc-client-test-discovery-openid-config" => ~w[send_init]a,
    "oidcc-client-test-discovery-webfinger-acct" => ~w[send_init]a,
    "oidcc-client-test-discovery-webfinger-url" => ~w[send_init]a,
    "oidcc-client-test-distributed-claims" => @login_success,
    "oidcc-client-test-dynamic-registration" => ~w[send_init register_client]a,
    # Log in and error are both ok
    "oidcc-client-test-idtoken-sig-none" => @login_success -- ~w[check_logged_in]a,
    "oidcc-client-test-idtoken-sig-rs256" => @login_success,
    "oidcc-client-test-invalid-aud" => @login_failure,
    "oidcc-client-test-invalid-iss" => @login_failure,
    "oidcc-client-test-invalid-sig-es256" => @login_failure,
    "oidcc-client-test-invalid-sig-hs256" => @login_failure,
    "oidcc-client-test-invalid-sig-rs256" => @login_failure,
    "oidcc-client-test-kid-absent-multiple-jwks" => @login_success,
    "oidcc-client-test-kid-absent-single-jwks" => @login_success,
    "oidcc-client-test-missing-aud" => @login_failure,
    "oidcc-client-test-missing-iat" => @login_failure,
    "oidcc-client-test-missing-sub" => @login_failure,
    "oidcc-client-test-nonce-invalid" => @login_failure,
    "oidcc-client-test-refresh-token" => @login_success ++ ~w[trigger_refresh check_logged_in]a,
    "oidcc-client-test-refresh-token-invalid-issuer" => @login_success ++ ~w[trigger_refresh check_login_error]a,
    "oidcc-client-test-refresh-token-invalid-sub" => @login_success ++ ~w[trigger_refresh check_login_error]a,
    "oidcc-client-test-request-uri-signed-none" => @login_success,
    "oidcc-client-test-request-uri-signed-rs256" => @login_success,
    "oidcc-client-test-scope-userinfo-claims" => @login_success,
    "oidcc-client-test-signing-key-rotation" => @login_success ++ ~w[open_browser trigger_login check_logged_in]a,
    "oidcc-client-test-signing-key-rotation-just-before-signing" => @login_success,
    "oidcc-client-test-userinfo-bearer-body" => @login_success,
    "oidcc-client-test-userinfo-bearer-header" => @login_success,
    "oidcc-client-test-userinfo-invalid-sub" => @login_failure,
    "oidcc-client-test-userinfo-signed" => @login_success
  }

  def run(opts) do
    plan = %__MODULE__{}

    opts = Map.new(opts)

    %__MODULE__{} =
      opts
      |> steps()
      |> Enum.reduce(plan, & &1.(&2, opts))

    :ok
  end

  defp steps(%{test_runner: %{"name" => test_name}}) do
    case @test_types[test_name] do
      nil -> raise "Test type not found for test: #{test_name}"
      steps -> Enum.map(steps, &Function.capture(__MODULE__, &1, 2))
    end
  end

  def send_init(%__MODULE__{} = state, opts) do
    implementation_name = opts |> :erlang.phash2() |> Integer.to_string()

    variant =
      case opts.test_runner["name"] do
        "oidcc-client-test-client-secret-basic" ->
          Map.put(opts.plan["variant"], "client_auth_type", "client_secret_basic")

        _other ->
          opts.plan["variant"]
      end

    assert {:ok, %{"url" => url, "port" => port}} =
             Implementation.command(opts.implementation, %{
               action: "init",
               exposed: opts.test_runner["exposed"],
               variant: variant,
               public_url: "https://#{LocalhostRun.get_exposed_host()}/#{implementation_name}",
               test_name: opts.test_runner["name"]
             })

    {:ok, _pid} = Registry.register(ImplementationRegistry, implementation_name, port)

    %{state | url: url}
  end

  def init_failure(%__MODULE__{} = state, opts) do
    implementation_name = opts |> :erlang.phash2() |> Integer.to_string()

    %Implementation{pid: implementation_pid, os_pid: implementation_os_pid} = opts.implementation

    opts.implementation
    |> Implementation.command(%{
      action: "init",
      exposed: opts.test_runner["exposed"],
      variant: opts.plan["variant"],
      public_url: "https://#{LocalhostRun.get_exposed_host()}/#{implementation_name}"
    })
    |> case do
      {:ok, _} ->
        assert_receive {:DOWN, ^implementation_os_pid, :process, ^implementation_pid, {:exit_status, _exit_status}},
                       to_timeout(second: 10)

      {:error, _reason} ->
        :ok
    end

    state
  end

  def register_client(state, opts) do
    dynamic? =
      cond do
        opts.plan["variant"]["client_registration"] == "dynamic_client" -> true
        opts.plan["variant"]["client_registration"] == "static_client" -> false
        opts.plan["name"] == "oidcc-client-dynamic-certification-test-plan" -> true
        true -> true
      end

    {client_id, client_secret} =
      if dynamic? do
        assert {:ok, %{"client_id" => client_id, "client_secret" => client_secret}} =
                 Implementation.command(opts.implementation, %{action: "register_client"})

        {client_id, client_secret}
      else
        {
          opts.plan["config"]["client"]["client_id"],
          opts.plan["config"]["client"]["client_secret"]
        }
      end

    %{state | client_config: %{client_id: client_id, client_secret: client_secret}}
  end

  def start_server(state, opts) do
    assert :ok ==
             Implementation.command(opts.implementation, %{
               action: "start_server",
               client_id: state.client_config.client_id,
               client_secret: state.client_config.client_secret
             })

    state
  end

  def open_browser(state, opts) do
    Wallaby.Browser.visit(opts.wallaby_session, state.url)

    take_screenshot(opts, "index_logged_out", false)

    state
  end

  def trigger_login(state, opts) do
    Wallaby.Browser.click(opts.wallaby_session, Wallaby.Query.css(~S|a[aria-label="Login"]|))

    state
  end

  def third_party_login(state, opts) do
    assert %Req.Response{status: 200, body: %{"urls" => [url | _rest]}} =
             ApiClient.test_browser_urls(opts.test_runner["id"])

    assert %Req.Response{status: 204} = ApiClient.test_browser_visit(opts.test_runner["id"], url)

    Wallaby.Browser.visit(opts.wallaby_session, url)

    state
  end

  def check_logged_in(state, opts) do
    assert_element(opts, Wallaby.Query.css(~S|[aria-label="sub"]|))
    assert_element(opts, Wallaby.Query.css(~S|[aria-label="token"]|))
    assert_element(opts, Wallaby.Query.css(~S|[aria-label="userinfo"]|))

    take_screenshot(opts, "logged_in", false)

    state
  end

  def check_login_error(state, opts) do
    assert_element(opts, Wallaby.Query.css(~S|[aria-label="error"]|))

    take_screenshot(opts, "login_error", false)

    state
  end

  def trigger_refresh(state, opts) do
    Wallaby.Browser.click(opts.wallaby_session, Wallaby.Query.css(~S|a[aria-label="Refresh"]|))

    state
  end

  defp assert_element(opts, query) do
    if Wallaby.Browser.has?(opts.wallaby_session, query) do
      assert true
    else
      take_screenshot(opts, "element_not_found", true)
      assert false, "Element not found: #{inspect(query)}"
    end
  end

  defp take_screenshot(
         %{wallaby_session: session, output_directory: output_directory, test: %{"id" => test_id}},
         name,
         upload?
       ) do
    %Wallaby.Session{screenshots: [screenshot]} = Wallaby.Browser.take_screenshot(session)

    path = Path.join(output_directory, "screenshot_#{name}.png")

    # Not renaming since the screenshot might be on a different filesystem
    File.cp!(screenshot, path)
    File.rm!(screenshot)

    if upload? do
      ApiClient.test_upload_screenshot(
        test_id,
        path,
        name
      )
    end
  end
end
