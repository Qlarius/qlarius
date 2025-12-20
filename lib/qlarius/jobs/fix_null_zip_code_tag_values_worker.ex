defmodule Qlarius.Jobs.FixNullZipCodeTagValuesWorker do
  @moduledoc """
  One-time worker to fix NULL tag_value in me_file_tags for Home Zip Code traits.

  ## Problem
  Prior to the fix, zip code tags were created with tag_value = zip_trait.trait_name,
  which could be NULL. This resulted in snapshots showing: [58587, null, 10028]
  instead of the correct: [58587, "10028", 10028].

  ## Solution
  This worker:
  1. Finds all me_file_tags with parent_trait_id = 4 (Home Zip Code) and NULL tag_value
  2. Attempts to recover the zip code from trait.trait_name or trait.meta_1
  3. Updates the tag_value with the recovered zip code
  4. Logs any records that cannot be fixed

  ## After Running
  The BackfillMissingSnapshotsWorker (runs hourly) will automatically regenerate
  snapshots for affected populations, offers, and ad_events using the corrected tag_values.

  ## Manual Execution

  To run this fix manually:

      Qlarius.Jobs.FixNullZipCodeTagValuesWorker.new(%{})
      |> Oban.insert()

  Or run immediately in console:

      Qlarius.Jobs.FixNullZipCodeTagValuesWorker.new(%{})
      |> Oban.insert()
      |> then(fn {:ok, job} ->
        Oban.drain_queue(queue: :maintenance, with_limit: 1)
      end)
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait

  @home_zip_code_parent_trait_id 4

  @doc """
  Diagnostic function to check what's actually in the database.
  Call this to see a sample of the data before running the fix.

  ## Example
      Qlarius.Jobs.FixNullZipCodeTagValuesWorker.diagnose()
  """
  def diagnose do
    require Logger

    # Check total zip code tags
    total_zip_tags =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where: t.parent_trait_id == ^@home_zip_code_parent_trait_id,
        select: count(mft.id)
      )
      |> Repo.one()

    Logger.info("Total Home Zip Code tags: #{total_zip_tags}")

    # Check NULL tag_value
    null_count =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where: t.parent_trait_id == ^@home_zip_code_parent_trait_id and is_nil(mft.tag_value),
        select: count(mft.id)
      )
      |> Repo.one()

    Logger.info("Tags with NULL tag_value: #{null_count}")

    # Check empty string tag_value
    empty_count =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where: t.parent_trait_id == ^@home_zip_code_parent_trait_id and mft.tag_value == "",
        select: count(mft.id)
      )
      |> Repo.one()

    Logger.info("Tags with empty string tag_value: #{empty_count}")

    # Get a sample
    sample =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where:
          t.parent_trait_id == ^@home_zip_code_parent_trait_id and
            (is_nil(mft.tag_value) or mft.tag_value == ""),
        limit: 5,
        preload: [:trait],
        select: mft
      )
      |> Repo.all()

    Logger.info("Sample of tags needing fix:")
    Enum.each(sample, fn tag ->
      Logger.info(
        "  MeFileTag ID: #{tag.id}, trait_id: #{tag.trait_id}, " <>
          "tag_value: #{inspect(tag.tag_value)}, " <>
          "trait.trait_name: #{inspect(tag.trait.trait_name)}, " <>
          "trait.meta_1: #{inspect(tag.trait.meta_1)}"
      )
    end)

    %{
      total: total_zip_tags,
      null_count: null_count,
      empty_count: empty_count,
      need_fix: null_count + empty_count,
      sample: sample
    }
  end

  @impl true
  def perform(%Oban.Job{args: _args}) do
    require Logger
    Logger.info("FixNullZipCodeTagValuesWorker: Starting zip code tag_value fix")

    tags_to_fix =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where:
          t.parent_trait_id == ^@home_zip_code_parent_trait_id and
            (is_nil(mft.tag_value) or mft.tag_value == ""),
        preload: [:trait],
        select: mft
      )
      |> Repo.all()

    total = length(tags_to_fix)

    if total > 0 do
      Logger.info("FixNullZipCodeTagValuesWorker: Found #{total} tags with NULL tag_value")

      fixed_count =
        Repo.transaction(fn ->
          Enum.reduce(tags_to_fix, 0, fn tag, count ->
            zip_code = get_zip_code_from_trait(tag.trait)

            if zip_code && valid_zip_code?(zip_code) do
              {updated, _} =
                from(mft in MeFileTag, where: mft.id == ^tag.id)
                |> Repo.update_all(set: [tag_value: zip_code])

              Logger.info(
                "FixNullZipCodeTagValuesWorker: Fixed tag ID #{tag.id} - set tag_value to '#{zip_code}'"
              )

              count + updated
            else
              Logger.warning(
                "FixNullZipCodeTagValuesWorker: Cannot fix tag ID #{tag.id} (trait #{tag.trait_id}) - " <>
                  "no valid zip code found (trait_name: #{inspect(tag.trait.trait_name)}, " <>
                  "meta_1: #{inspect(tag.trait.meta_1)})"
              )

              count
            end
          end)
        end)

      case fixed_count do
        {:ok, count} ->
          Logger.info(
            "FixNullZipCodeTagValuesWorker: ✅ COMPLETE - Fixed #{count} of #{total} tags"
          )

          if count < total do
            Logger.warning(
              "FixNullZipCodeTagValuesWorker: #{total - count} tags could not be fixed automatically"
            )
          end

          :ok

        {:error, reason} ->
          Logger.error(
            "FixNullZipCodeTagValuesWorker: ❌ Transaction failed: #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      Logger.info("FixNullZipCodeTagValuesWorker: No tags with NULL tag_value found")
      :ok
    end
  end

  defp get_zip_code_from_trait(trait) do
    trait.trait_name || trait.meta_1
  end

  defp valid_zip_code?(zip_code) when is_binary(zip_code) do
    String.match?(zip_code, ~r/^\d{5}$/)
  end

  defp valid_zip_code?(_), do: false
end
