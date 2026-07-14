defmodule Fireside.Repo do
  use Ecto.Repo,
    otp_app: :fireside,
    adapter: Ecto.Adapters.SQLite3
end
