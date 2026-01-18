defmodule Qlarius.Sponster.Campaigns.MediaSequences do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{MediaSequence, MediaRun}

  @doc """
  Lists all active (non-archived) media sequences for a marketer with their media runs and campaigns preloaded.
  """
  def list_media_sequences_for_marketer(marketer_id) do
    from(ms in MediaSequence,
      where: ms.marketer_id == ^marketer_id and is_nil(ms.archived_at),
      order_by: [desc: ms.created_at],
      preload: [media_runs: :media_piece, campaigns: []]
    )
    |> Repo.all()
  end

  @doc """
  Lists all archived media sequences for a marketer with their media runs preloaded.
  """
  def list_archived_media_sequences_for_marketer(marketer_id) do
    from(ms in MediaSequence,
      where: ms.marketer_id == ^marketer_id and not is_nil(ms.archived_at),
      order_by: [desc: ms.archived_at],
      preload: [media_runs: :media_piece]
    )
    |> Repo.all()
  end

  @doc """
  Creates a media sequence with its associated media run.

  ## Parameters
    - marketer_id: The marketer's ID
    - attrs: Map containing:
      - media_piece_id
      - frequency
      - frequency_buffer_hours
      - maximum_banner_count (optional - defaults to 1 for video types)
      - banner_retry_buffer_hours (optional - defaults to 1 for video types)
      - title (optional - will auto-generate if not provided)
  """
  def create_media_sequence_with_run(marketer_id, attrs) do
    Repo.transaction(fn ->
      sequence_attrs = %{
        title: attrs["title"] || attrs[:title],
        description: attrs["description"] || attrs[:description],
        marketer_id: marketer_id
      }

      case Repo.insert(MediaSequence.changeset(%MediaSequence{}, sequence_attrs)) do
        {:ok, sequence} ->
          media_run_attrs = %{
            media_sequence_id: sequence.id,
            media_piece_id: attrs["media_piece_id"] || attrs[:media_piece_id],
            marketer_id: marketer_id,
            sequence_start_phase: 1,
            sequence_end_phase: 1,
            frequency: attrs["frequency"] || attrs[:frequency],
            frequency_buffer_hours:
              attrs["frequency_buffer_hours"] || attrs[:frequency_buffer_hours],
            maximum_banner_count:
              attrs["maximum_banner_count"] || attrs[:maximum_banner_count] || 1,
            banner_retry_buffer_hours:
              attrs["banner_retry_buffer_hours"] || attrs[:banner_retry_buffer_hours] || 1,
            is_active: true
          }

          case Repo.insert(MediaRun.changeset(%MediaRun{}, media_run_attrs)) do
            {:ok, _media_run} -> sequence
            {:error, changeset} -> Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Deletes a media sequence and its associated media runs.
  Returns error if the sequence is in use by any active campaigns.
  """
  def delete_media_sequence(sequence) do
    active_campaign_count =
      Repo.one(
        from c in "campaigns",
          where: c.media_sequence_id == ^sequence.id and is_nil(c.deactivated_at),
          select: count(c.id)
      )

    if active_campaign_count > 0 do
      {:error, :sequence_in_use}
    else
      Repo.delete(sequence)
    end
  end

  @doc """
  Archives a media sequence by setting archived_at to current timestamp.
  """
  def archive_media_sequence(sequence) do
    sequence
    |> Ecto.Changeset.change(%{
      archived_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.update()
  end

  @doc """
  Unarchives a media sequence by setting archived_at to nil.
  """
  def unarchive_media_sequence(sequence) do
    sequence
    |> Ecto.Changeset.change(%{archived_at: nil})
    |> Repo.update()
  end

  @doc """
  Generates a default name for a media sequence.

  Format for 3-tap: {media_piece_type} :: {media_piece_title} :: {frequency}/{buffer} :: {banner_count}/{retry_buffer}
  Format for video: {media_piece_type} :: {media_piece_title} :: {frequency}/{buffer}
  Example: "3-Tap :: Modern Furniture :: 3/24 :: 3/10"
  Example: "Video :: Product Demo :: 3/24"
  """
  def generate_sequence_name(media_piece, frequency, buffer, banner_count, retry_buffer) do
    media_type =
      if media_piece.media_piece_type do
        media_piece.media_piece_type.name
      else
        "Media"
      end

    media_title = media_piece.title || "Untitled"
    is_video = media_piece.media_piece_type_id == 2

    if is_video do
      "#{media_type} :: #{media_title} :: #{frequency}/#{buffer}"
    else
      "#{media_type} :: #{media_title} :: #{frequency}/#{buffer} :: #{banner_count}/#{retry_buffer}"
    end
  end

  @doc """
  Gets a media sequence for a marketer with preloaded associations.
  Raises if not found or doesn't belong to marketer.
  """
  def get_media_sequence_for_marketer!(id, marketer_id) do
    Repo.one!(
      from ms in MediaSequence,
        where: ms.id == ^id and ms.marketer_id == ^marketer_id,
        preload: [media_runs: :media_piece]
    )
  end
end
