defmodule Qlarius.LegacyRepo do
  use Ecto.Repo,
    otp_app: :qlarius,
    adapter: Ecto.Adapters.Postgres
end
