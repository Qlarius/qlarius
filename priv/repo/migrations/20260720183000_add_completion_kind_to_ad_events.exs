defmodule Qlarius.Repo.Migrations.AddCompletionKindToAdEvents do
  use Ecto.Migration

  def change do
    alter table(:ad_events) do
      # "full_funnel" = successful jump/video completion (engagement reporting).
      # "banner_max" = attempt ended by maximum_banner_count without jump
      # (counts toward media_run frequency, excluded from engagement reporting).
      # NULL on legacy rows / non-complete phase events.
      add :completion_kind, :string
    end

    create index(:ad_events, [:completion_kind],
      where: "is_offer_complete = true",
      name: :ad_events_complete_completion_kind_idx
    )
  end
end
