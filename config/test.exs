import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :elixir_ctf, ElixirCtfWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "oL0+xUv6FY8HfSncnE0DkEnzXku8g4mfYmLr7PK94rNGbT+fe/VVvnuh/6+werro",
  server: false

# In test we don't send emails.
config :elixir_ctf, ElixirCtf.Mailer,
  adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
