defmodule Qlarius.Repo do
  use Ecto.Repo,
    otp_app: :qlarius,
    adapter: Ecto.Adapters.Postgres

  def count(queryable), do: aggregate(queryable, :count)
end
