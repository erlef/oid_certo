defmodule OIDCerto.ApiClient do
  @moduledoc false
  @spec client() :: Keyword.t()
  defp client do
    config = Application.get_env(:oid_certo, __MODULE__, [])

    Keyword.merge(
      [
        # connect_options: [transport_opts: [cacerts: :public_key.cacerts_get()]],
        headers: [
          authorization: "Bearer #{Keyword.fetch!(config, :token)}"
        ],
        retry: :safe_transient
      ],
      Keyword.take(config, [:base_url, :plug])
    )
  end

  def test_status(test_id) do
    Req.request!(client(), url: "/api/runner/:id", path_params: [id: test_id])
  end

  def test_export(test_id) do
    Req.request!(client(), url: "/api/plan/export/:id", path_params: [id: test_id])
  end

  def test_logs(test_id) do
    Req.request!(client(), url: "/api/log/:id", path_params: [id: test_id])
  end

  def test_logs_html(test_id) do
    Req.request!(client(), url: "/api/log/exporthtml/:id", path_params: [id: test_id])
  end

  def test_info(test_id) do
    Req.request!(client(), url: "/api/info/:id", path_params: [id: test_id])
  end

  def test_create(plan_id, test_name) do
    Req.request!(client(), method: :post, url: "/api/runner", params: [test: test_name, plan: plan_id])
  end

  def test_start(test_id) do
    Req.request!(client(), method: :post, url: "/api/runner/:id", path_params: [id: test_id])
  end

  def test_browser_urls(test_id) do
    Req.request!(client(), url: "/api/runner/browser/:id", path_params: [id: test_id])
  end

  def test_browser_visit(test_id, url) do
    Req.request!(client(),
      method: :post,
      url: "/api/runner/browser/:id/visit",
      path_params: [id: test_id],
      params: [url: url]
    )
  end

  def test_upload_screenshot(test_id, screenshot_path, description) do
    Req.request!(client(),
      method: :post,
      url: "/api/log/:id/images",
      path_params: [id: test_id],
      params: [description: description],
      body:
        IO.iodata_to_binary([
          "data:",
          MIME.from_path(screenshot_path),
          ";base64,",
          Base.encode64(File.read!(screenshot_path))
        ])
    )
  end

  def plan_create(name, variant, config) do
    Req.request!(client(),
      method: :post,
      url: "/api/plan",
      params: [
        planName: name,
        variant: JSON.encode!(variant)
      ],
      json: config
    )
  end

  def plan_info(plan_id) do
    Req.request!(client(), url: "/api/plan/:id", path_params: [id: plan_id])
  end

  def plan_delete(plan_id) do
    Req.request!(client(), method: :delete, url: "/api/plan/:id", path_params: [id: plan_id])
  end

  def plans_list(pageination \\ []) do
    Req.request!(client(), url: "/api/plan", params: pageination)
  end
end
