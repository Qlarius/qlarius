# https://hexdocs.pm/phoenix/releases.html#ecto-migrations-and-custom-commands
defmodule Qlarius.Release do
  @app :qlarius

  alias Qlarius.Repo

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def migrations() do
    {:ok, migrations, _} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.migrations(&1))

    for {status, timestamp, name} <- migrations do
      IO.puts("#{status} #{timestamp} #{name}")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end

