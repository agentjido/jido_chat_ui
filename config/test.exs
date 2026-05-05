import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :jido_chat_ui, JidoChatUI.Mailer, adapter: Swoosh.Adapters.Test

# Avoid bridge-supervisor reconcile tasks crossing SQL sandbox owner lifetimes.
# Dedicated persistence tests exercise the same Postgres adapter directly.
config :jido_chat_ui, :messaging_sync_mode, :direct_persistence
config :jido_chat_ui, :start_bridge_reconciler, false
config :jido_chat_ui, :start_agent_responder, false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :jido_chat_ui, JidoChatUI.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "jido_chat_ui_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :jido_chat_ui, JidoChatUIWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "N9Kq6v4TNcmArBziYZa9CBVVhETiKB++7HWlIU3YkU2K9xaS7Kuqc/L2ZZ5zm1AM",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
