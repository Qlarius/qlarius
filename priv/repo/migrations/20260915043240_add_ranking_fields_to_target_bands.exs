defmodule Qlarius.Repo.Migrations.AddRankingFieldsToTargetBands do
  use Ecto.Migration

  # Three additive columns that content ranking and population reuse need:
  #
  #   tier             — stable ring position. Today it is re-derived on every
  #                      read from `length(band.trait_groups)` in
  #                      `Targets.sort_bands_by_trait_count/1`, which ties
  #                      unpredictably between bands holding the same number of
  #                      groups. Content ordering needs a rank that does not
  #                      shuffle between requests.
  #   population_count — selectivity signal for ranking, so a narrow audience
  #                      outranks a broad one.
  #   definition_hash  — content fingerprint of the band's trait sets, which is
  #                      what lets identical bands share one population scan.
  #
  # All nullable, so the ad path keeps inferring ring order as it does now
  # until it is deliberately switched over.

  def change do
    alter table(:target_bands) do
      add :tier, :integer
      add :population_count, :integer
      add :definition_hash, :string
    end

    create index(:target_bands, [:definition_hash])

    # Backfill tier to match the current descending trait-group-count order,
    # with id as the tiebreak that ordering lacks. Tier 0 is the most
    # restrictive band, matching "Ring 0" in `Targets.band_label/2`.
    #
    # Deliberately raw SQL rather than Ecto: a data backfill must keep working
    # against the schema as it was the day it was written, so it must not
    # reference `TargetBand`, which will drift. Reverse is a no-op because
    # rolling back drops the column.
    execute(
      """
      WITH ranked AS (
        SELECT tb.id,
               ROW_NUMBER() OVER (
                 PARTITION BY tb.target_id
                 ORDER BY COALESCE(g.cnt, 0) DESC, tb.id ASC
               ) - 1 AS tier
          FROM target_bands tb
          LEFT JOIN (
            SELECT target_band_id, COUNT(*) AS cnt
              FROM target_band_trait_groups
             GROUP BY target_band_id
          ) g ON g.target_band_id = tb.id
      )
      UPDATE target_bands tb
         SET tier = ranked.tier
        FROM ranked
       WHERE ranked.id = tb.id;
      """,
      ""
    )
  end
end
