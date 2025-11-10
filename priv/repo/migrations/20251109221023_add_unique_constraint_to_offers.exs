defmodule Qlarius.Repo.Migrations.AddUniqueConstraintToOffers do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM offers o1
    USING offers o2
    WHERE o1.id > o2.id
      AND o1.campaign_id = o2.campaign_id
      AND o1.me_file_id = o2.me_file_id
      AND o1.media_run_id = o2.media_run_id
    """

    create unique_index(:offers, [:campaign_id, :me_file_id, :media_run_id],
             name: :offers_campaign_me_file_media_run_unique_index
           )
  end

  def down do
    drop index(:offers, [:campaign_id, :me_file_id, :media_run_id],
           name: :offers_campaign_me_file_media_run_unique_index
         )
  end
end
