defmodule Qlarius.Repo.Migrations.AddSourceToMecpTagSuggestions do
  use Ecto.Migration

  # Hybrid suggestion loop: "assistant" rows come from an explicit suggest_tag
  # call; "observed" rows are queued by MeCP itself when a read hits a gap
  # (empty ask_me answer, search_traits match without data).
  def change do
    alter table(:mecp_tag_suggestions) do
      add :source, :string, null: false, default: "assistant"
    end
  end
end
