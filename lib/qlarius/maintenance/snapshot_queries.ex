defmodule Qlarius.Maintenance.SnapshotQueries do
  @moduledoc """
  Utility queries for analyzing and comparing matching_tags_snapshot data
  across target_populations, offers, and ad_events tables.

  This module provides diagnostic and comparison tools for snapshot data integrity.

  ## Usage Examples

      # Find all ad_events with Home Zip Code trait (trait_id = 4)
      Qlarius.Maintenance.SnapshotQueries.with_trait(Qlarius.Sponster.AdEvent, 4)

      # Find all offers with zip code "02140"
      Qlarius.Maintenance.SnapshotQueries.with_tag_value(Qlarius.Sponster.Offer, 4, "02140")

      # Find all target_populations with NULL zip code values
      Qlarius.Maintenance.SnapshotQueries.with_null_tag_value(Qlarius.Sponster.TargetPopulation, 4)

      # Find all mismatches between tables
      Qlarius.Maintenance.SnapshotQueries.find_snapshot_mismatches()

      # Extract a specific trait value from a snapshot
      snapshot = %{"tags" => [[4, "Home Zip Code", 1, [[58587, "02140", 10028]]]]}
      Qlarius.Maintenance.SnapshotQueries.extract_trait_value(snapshot, 4)

      # Get all records needing fixes
      Qlarius.Maintenance.SnapshotQueries.records_needing_snapshot_fix()
  """

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.{AdEvent, Offer}
  alias Qlarius.Sponster.Campaigns.TargetPopulation

  @doc """
  Find all records in a table where matching_tags_snapshot contains a specific parent trait.

  ## Parameters
  - `table`: The Ecto schema module (AdEvent, Offer, or TargetPopulation)
  - `parent_trait_id`: The ID of the parent trait to search for

  ## Examples

      iex> with_trait(AdEvent, 4)
      [%AdEvent{...}, ...]
  """
  def with_trait(table, parent_trait_id) do
    # Get all records with non-null snapshots
    from(t in table,
      where: not is_nil(t.matching_tags_snapshot)
    )
    |> Repo.all()
    |> Enum.filter(&has_trait?(&1, parent_trait_id))
  end

  @doc """
  Find records with a specific child tag value.

  ## Parameters
  - `table`: The Ecto schema module
  - `parent_trait_id`: The parent trait ID (e.g., 4 for "Home Zip Code")
  - `tag_value`: The exact tag value to match (e.g., "02140")

  ## Examples

      iex> with_tag_value(Offer, 4, "02140")
      [%Offer{...}, ...]
  """
  def with_tag_value(table, parent_trait_id, tag_value) do
    # Search for the tag value in the JSONB text (cast to text first)
    from(t in table,
      where: not is_nil(t.matching_tags_snapshot),
      where: fragment("CAST(? AS text) LIKE ?", t.matching_tags_snapshot, ^"%#{tag_value}%")
    )
    |> Repo.all()
    |> Enum.filter(&has_tag_value?(&1, parent_trait_id, tag_value))
  end

  @doc """
  Find records with NULL or empty string tag_value for a specific trait.

  ## Parameters
  - `table`: The Ecto schema module
  - `parent_trait_id`: The parent trait ID

  ## Examples

      iex> with_null_tag_value(TargetPopulation, 4)
      [%TargetPopulation{...}, ...]
  """
  def with_null_tag_value(table, parent_trait_id) do
    # Search for JSON null values (not quoted strings containing "null")
    # Look for patterns: ", null," or "[null," or ", null]"
    from(t in table,
      where: not is_nil(t.matching_tags_snapshot),
      where:
        fragment(
          "CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ?",
          t.matching_tags_snapshot,
          "%, null,%",
          t.matching_tags_snapshot,
          "%[null,%",
          t.matching_tags_snapshot,
          "%, null]%",
          t.matching_tags_snapshot,
          "%\"\",%"
        )
    )
    |> Repo.all()
    |> Enum.filter(&has_null_value_for_trait?(&1, parent_trait_id))
  end

  @doc """
  Compare snapshots between tables for the same me_file and target_band.
  Returns records where snapshots don't match or are NULL.

  ## Returns
  List of maps with:
  - `:me_file_id`
  - `:target_band_id`
  - `:tp_snapshot` - target_population snapshot
  - `:offer_snapshot` - offer snapshot
  - `:ad_event_snapshot` - ad_event snapshot
  - `:all_match` - boolean indicating if all three match

  ## Examples

      iex> find_snapshot_mismatches()
      [
        %{
          me_file_id: 13925,
          target_band_id: 1,
          tp_snapshot: %{"tags" => [...]},
          offer_snapshot: nil,
          ad_event_snapshot: %{"tags" => [...]},
          all_match: false
        },
        ...
      ]
  """
  def find_snapshot_mismatches(limit \\ 100) do
    query = """
    SELECT DISTINCT
      tp.me_file_id,
      tp.target_band_id,
      tp.matching_tags_snapshot as tp_snapshot,
      o.matching_tags_snapshot as offer_snapshot,
      ae.matching_tags_snapshot as ad_event_snapshot
    FROM target_populations tp
    LEFT JOIN offers o ON o.me_file_id = tp.me_file_id AND o.target_band_id = tp.target_band_id
    LEFT JOIN ad_events ae ON ae.me_file_id = tp.me_file_id AND ae.target_band_id = tp.target_band_id
    WHERE
      tp.matching_tags_snapshot IS NOT NULL
      AND (
        o.matching_tags_snapshot IS NULL
        OR ae.matching_tags_snapshot IS NULL
        OR tp.matching_tags_snapshot != o.matching_tags_snapshot
        OR tp.matching_tags_snapshot != ae.matching_tags_snapshot
      )
    LIMIT $1
    """

    {:ok, result} = Repo.query(query, [limit])

    Enum.map(result.rows, fn [me_file_id, target_band_id, tp_snap, o_snap, ae_snap] ->
      %{
        me_file_id: me_file_id,
        target_band_id: target_band_id,
        tp_snapshot: tp_snap,
        offer_snapshot: o_snap,
        ad_event_snapshot: ae_snap,
        all_match: tp_snap == o_snap && tp_snap == ae_snap
      }
    end)
  end

  @doc """
  Pattern match and extract a specific trait value from a snapshot structure.

  ## Parameters
  - `snapshot`: The matching_tags_snapshot map/JSONB structure
  - `parent_trait_id`: The parent trait ID to extract

  ## Returns
  - `{:ok, tag_value}` if found
  - `{:error, :not_found}` if not found

  ## Examples

      iex> snapshot = %{"tags" => [[4, "Home Zip Code", 1, [[58587, "02140", 10028]]]]}
      iex> extract_trait_value(snapshot, 4)
      {:ok, "02140"}

      iex> extract_trait_value(%{"tags" => []}, 999)
      {:error, :not_found}
  """
  def extract_trait_value(%{"tags" => tags}, parent_trait_id) when is_list(tags) do
    with [_parent_id, _parent_name, _order, child_tags] <-
           Enum.find(tags, fn [id, _name, _order, _children] -> id == parent_trait_id end),
         [_child_id, tag_value, _order] <- List.first(child_tags) do
      {:ok, tag_value}
    else
      _ -> {:error, :not_found}
    end
  end

  def extract_trait_value(_, _), do: {:error, :invalid_snapshot}

  @doc """
  Get all records with mismatched or NULL snapshots across all three tables.

  ## Returns
  List of maps with diagnostic information:
  - `:me_file_id`
  - `:target_band_id`
  - `:tp_null` - is target_population snapshot NULL?
  - `:offer_null` - is offer snapshot NULL?
  - `:ad_event_null` - is ad_event snapshot NULL?
  - `:issue_type` - description of the issue

  ## Examples

      iex> records_needing_snapshot_fix()
      [
        %{
          me_file_id: 13925,
          target_band_id: 1,
          tp_null: false,
          offer_null: true,
          ad_event_null: false,
          issue_type: "offer"
        },
        ...
      ]
  """
  def records_needing_snapshot_fix do
    query = """
    SELECT
      tp.me_file_id,
      tp.target_band_id,
      tp.matching_tags_snapshot IS NULL as tp_null,
      o.matching_tags_snapshot IS NULL as offer_null,
      ae.matching_tags_snapshot IS NULL as ad_event_null,
      CASE
        WHEN tp.matching_tags_snapshot IS NULL THEN 'target_population'
        WHEN o.matching_tags_snapshot IS NULL THEN 'offer'
        WHEN ae.matching_tags_snapshot IS NULL THEN 'ad_event'
        WHEN tp.matching_tags_snapshot != o.matching_tags_snapshot THEN 'offer_mismatch'
        WHEN tp.matching_tags_snapshot != ae.matching_tags_snapshot THEN 'ad_event_mismatch'
      END as issue_type
    FROM target_populations tp
    LEFT JOIN offers o ON o.me_file_id = tp.me_file_id AND o.target_band_id = tp.target_band_id
    LEFT JOIN ad_events ae ON ae.me_file_id = tp.me_file_id AND ae.target_band_id = tp.target_band_id
    WHERE
      tp.matching_tags_snapshot IS NULL
      OR o.matching_tags_snapshot IS NULL
      OR ae.matching_tags_snapshot IS NULL
      OR tp.matching_tags_snapshot != o.matching_tags_snapshot
      OR tp.matching_tags_snapshot != ae.matching_tags_snapshot
    """

    {:ok, result} = Repo.query(query)

    Enum.map(result.rows, fn [me_file_id, target_band_id, tp_null, o_null, ae_null, issue_type] ->
      %{
        me_file_id: me_file_id,
        target_band_id: target_band_id,
        tp_null: tp_null,
        offer_null: o_null,
        ad_event_null: ae_null,
        issue_type: issue_type
      }
    end)
  end

  @doc """
  Count records by issue type for quick diagnostics.

  ## Examples

      iex> count_by_issue_type()
      %{
        target_population: 5,
        offer: 120,
        ad_event: 35,
        offer_mismatch: 2,
        ad_event_mismatch: 1,
        total: 163
      }
  """
  def count_by_issue_type do
    records = records_needing_snapshot_fix()

    counts =
      records
      |> Enum.group_by(& &1.issue_type)
      |> Enum.map(fn {type, list} -> {String.to_atom(type), length(list)} end)
      |> Map.new()

    Map.put(counts, :total, length(records))
  end

  @doc """
  Sample a few records from each table to inspect snapshot structure.

  ## Parameters
  - `limit`: Number of records to sample from each table (default: 5)

  ## Examples

      iex> sample_snapshots(3)
      %{
        target_populations: [...],
        offers: [...],
        ad_events: [...]
      }
  """
  def sample_snapshots(limit \\ 5) do
    %{
      target_populations:
        from(tp in TargetPopulation,
          where: not is_nil(tp.matching_tags_snapshot),
          limit: ^limit,
          select: %{id: tp.id, me_file_id: tp.me_file_id, snapshot: tp.matching_tags_snapshot}
        )
        |> Repo.all(),
      offers:
        from(o in Offer,
          where: not is_nil(o.matching_tags_snapshot),
          limit: ^limit,
          select: %{id: o.id, me_file_id: o.me_file_id, snapshot: o.matching_tags_snapshot}
        )
        |> Repo.all(),
      ad_events:
        from(ae in AdEvent,
          where: not is_nil(ae.matching_tags_snapshot),
          limit: ^limit,
          select: %{id: ae.id, me_file_id: ae.me_file_id, snapshot: ae.matching_tags_snapshot}
        )
        |> Repo.all()
    }
  end

  # Private helper to check if a record has a specific trait
  defp has_trait?(%{matching_tags_snapshot: %{"tags" => tags}}, parent_trait_id) do
    Enum.any?(tags, fn
      [^parent_trait_id, _name, _order, _child_tags] -> true
      _ -> false
    end)
  end

  defp has_trait?(_, _), do: false

  # Private helper to check if a record has a specific tag value for a trait
  defp has_tag_value?(%{matching_tags_snapshot: %{"tags" => tags}}, parent_trait_id, tag_value) do
    Enum.any?(tags, fn
      [^parent_trait_id, _name, _order, child_tags] ->
        Enum.any?(child_tags, fn
          [_id, ^tag_value, _order] -> true
          _ -> false
        end)

      _ ->
        false
    end)
  end

  defp has_tag_value?(_, _, _), do: false

  # Private helper to check if a record has a null value for a specific trait
  defp has_null_value_for_trait?(%{matching_tags_snapshot: %{"tags" => tags}}, parent_trait_id) do
    Enum.any?(tags, fn
      [^parent_trait_id, _name, _order, child_tags] ->
        Enum.any?(child_tags, fn
          [_id, nil, _order] -> true
          [_id, "", _order] -> true
          _ -> false
        end)

      _ ->
        false
    end)
  end

  defp has_null_value_for_trait?(_, _), do: false
end
