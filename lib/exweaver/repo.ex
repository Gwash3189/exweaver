defmodule Exweaver.Repo do
  use Ecto.Repo,
    otp_app: :exweaver,
    adapter: Ecto.Adapters.SQLite3
end
