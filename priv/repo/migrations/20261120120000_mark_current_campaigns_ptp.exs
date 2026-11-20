defmodule Qlarius.Repo.Migrations.MarkCurrentCampaignsPtp do
  use Ecto.Migration

  def up do
    execute """
    UPDATE campaigns AS c
    SET is_ptp = NOT EXISTS (
      SELECT 1
      FROM marketers AS m
      WHERE m.id = c.marketer_id
        AND (
          lower(btrim(m.business_name)) IN ('qadabra', 'qlarius')
          OR lower(m.business_name) LIKE 'qadabra %'
          OR lower(m.business_name) LIKE 'qlarius %'
        )
    )
    """
  end

  def down do
    :ok
  end
end
