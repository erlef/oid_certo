import Config

config :logger, :default_formatter,
  format: "[$level] $message $metadata\n",
  metadata: [:plan, :plan_id, :test, :test_id, :internal_id, :os_pid, :device]
