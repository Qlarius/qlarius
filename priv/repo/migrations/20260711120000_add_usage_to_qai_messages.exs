defmodule Qlarius.Repo.Migrations.AddUsageToQaiMessages do
  use Ecto.Migration

  # Provider token usage per assistant message (input/output/cache fields as
  # returned by the API, summed across tool rounds). Raw material for the
  # unit-economics livebook and eventual wallet settlement; jsonb so new
  # provider fields land without migrations.
  def change do
    alter table(:qai_messages) do
      add :usage, :map, null: false, default: %{}
    end
  end
end
