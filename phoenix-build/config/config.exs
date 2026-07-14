# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :fireside,
  ecto_repos: [Fireside.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :fireside, FiresideWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FiresideWeb.ErrorHTML, json: FiresideWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Fireside.PubSub,
  live_view: [signing_salt: "QwlCLkzh"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild. `path:` (env `ESBUILD_PATH`) points at an npm-installed CLI instead of
# downloading a binary; when unset it falls back to the default download-based install.
config :esbuild,
  path: System.get_env("ESBUILD_PATH"),
  fireside: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind. `path:` (env `TAILWIND_PATH`) points at an npm-installed CLI instead of
# downloading a binary; when unset it falls back to the default download-based install.
config :tailwind,
  path: System.get_env("TAILWIND_PATH"),
  fireside: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
