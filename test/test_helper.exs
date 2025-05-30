alias OIDCerto.ApiClient

Application.put_env(:oid_certo, ApiClient, plug: {Req.Test, ApiClient})

ExUnit.start(capture_log: true)
