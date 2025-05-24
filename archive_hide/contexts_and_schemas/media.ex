defmodule Qlarius.Media do
  @moduledoc """
  The Media context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Sponster.Campaigns.MediaSequence
  alias Qlarius.Sponster.Campaigns.MediaRun
  alias Qlarius.Sponster.Ads.MediaPiece

  @doc """
  Returns the list of media_sequences.
  """
  def list_media_sequences do
    Repo.all(MediaSequence)
  end

  @doc """
  Gets a single media_sequence.
  Raises `Ecto.NoResultsError` if the Media sequence does not exist.
  """
  def get_media_sequence!(id), do: Repo.get!(MediaSequence, id)

  @doc """
  Creates a media_sequence.
  """
  def create_media_sequence(attrs \\ %{}) do
    %MediaSequence{}
    |> MediaSequence.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a media_sequence.
  """
  def update_media_sequence(%MediaSequence{} = media_sequence, attrs) do
    media_sequence
    |> MediaSequence.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media_sequence.
  """
  def delete_media_sequence(%MediaSequence{} = media_sequence) do
    Repo.delete(media_sequence)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_sequence changes.
  """
  def change_media_sequence(%MediaSequence{} = media_sequence, attrs \\ %{}) do
    MediaSequence.changeset(media_sequence, attrs)
  end

  @doc """
  Creates a media run with an associated media sequence in a transaction.
  """
  def create_media_run_with_sequence(attrs) do
    Repo.transaction(fn ->
      # Get the media piece to use its attributes for the sequence title
      media_piece = Repo.get!(MediaPiece, attrs["media_piece_id"])

      # Create the sequence title from media piece attributes and run parameters
      sequence_title =
        "#{media_piece.display_url} | #{media_piece.title} | #{attrs["frequency"]}:#{attrs["frequency_buffer_hours"]}:#{attrs["maximum_banner_count"]}:#{attrs["banner_retry_buffer_hours"]}"

      # Create the media sequence
      sequence_result = create_media_sequence(%{title: sequence_title})

      case sequence_result do
        {:ok, sequence} ->
          # Create the media run with association to the sequence
          media_run_attrs = Map.put(attrs, "media_sequence_id", sequence.id)

          case create_media_run(media_run_attrs) do
            {:ok, media_run} -> media_run
            {:error, changeset} -> Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates a media_run.
  """
  def create_media_run(attrs \\ %{}) do
    %MediaRun{}
    |> MediaRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_run changes.
  """
  def change_media_run(%MediaRun{} = media_run, attrs \\ %{}) do
    MediaRun.changeset(media_run, attrs)
  end

  @doc """
  Returns the list of media pieces for dropdown selection.
  """
  def list_media_pieces_for_select do
    MediaPiece
    |> order_by(asc: :title)
    |> Repo.all()
  end
end
