defmodule Qlarius.Sponster.Campaigns.MediaSequences do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPiece
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
  Creates a sequence from a media piece.

  The piece must already exist. A run is that piece plus frequency rules, and
  a sequence is the container for its runs. Today that is one run. The sequence
  row is inserted first only because the run stores its id.
  """
  def create_media_sequence_with_run(marketer_id, attrs) do
    with {:ok, piece} <- fetch_piece(marketer_id, attrs) do
      run_attrs = run_attrs(marketer_id, piece.id, attrs)

      # Prove the run is complete before writing the sequence. The sequence id
      # is filled in during the insert; the piece id has to be real now.
      case MediaRun.changeset(%MediaRun{}, Map.put(run_attrs, "media_sequence_id", 0)) do
        %{valid?: true} -> insert_sequence_and_run(marketer_id, attrs, run_attrs)
        changeset -> {:error, changeset}
      end
    end
  end

  defp fetch_piece(marketer_id, attrs) do
    case attrs["media_piece_id"] || attrs[:media_piece_id] do
      id when id in [nil, ""] ->
        {:error, :media_piece_required}

      id ->
        case Repo.get(MediaPiece, id) do
          %MediaPiece{marketer_id: mid} = piece when mid == marketer_id -> {:ok, piece}
          %MediaPiece{} -> {:error, :media_piece_wrong_marketer}
          nil -> {:error, :media_piece_required}
        end
    end
  end

  defp run_attrs(marketer_id, media_piece_id, attrs) do
    %{
      "media_piece_id" => media_piece_id,
      "marketer_id" => marketer_id,
      "sequence_start_phase" => 1,
      "sequence_end_phase" => 1,
      "frequency" => attrs["frequency"] || attrs[:frequency],
      "frequency_buffer_hours" =>
        attrs["frequency_buffer_hours"] || attrs[:frequency_buffer_hours],
      "maximum_banner_count" =>
        attrs["maximum_banner_count"] || attrs[:maximum_banner_count] || 1,
      "banner_retry_buffer_hours" =>
        attrs["banner_retry_buffer_hours"] || attrs[:banner_retry_buffer_hours] || 1,
      "is_active" => true
    }
  end

  defp insert_sequence_and_run(marketer_id, attrs, run_attrs) do
    Repo.transaction(fn ->
      sequence_attrs = %{
        title: attrs["title"] || attrs[:title],
        description: attrs["description"] || attrs[:description],
        marketer_id: marketer_id
      }

      case Repo.insert(MediaSequence.changeset(%MediaSequence{}, sequence_attrs)) do
        {:ok, sequence} ->
          run_attrs = Map.put(run_attrs, "media_sequence_id", sequence.id)

          case Repo.insert(MediaRun.changeset(%MediaRun{}, run_attrs)) do
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
