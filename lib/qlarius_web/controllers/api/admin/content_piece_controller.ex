defmodule QlariusWeb.Api.Admin.ContentPieceController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.{ContentGroups, ContentPieces}
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, %{"content_group_id" => group_id} = params) do
    case ContentGroups.fetch(group_id) do
      {:ok, group} ->
        pieces = ContentPieces.list(group, params)
        json(conn, %{count: length(pieces), content_pieces: Enum.map(pieces, &piece_json/1)})

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    case ContentPieces.fetch(id) do
      {:ok, piece} -> json(conn, %{content_piece: piece_json(piece)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, %{"content_group_id" => group_id} = params) do
    with {:ok, group} <- ContentGroups.fetch(group_id),
         {:ok, result} <- ContentPieces.create(group, params, dry_run: Responder.dry_run?(params)) do
      conn = if result.result == "created", do: put_status(conn, 201), else: conn
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, piece} <- ContentPieces.fetch(id),
         {:ok, result} <- ContentPieces.update(piece, params, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def reorder(conn, %{"content_group_id" => group_id} = params) do
    with {:ok, group} <- ContentGroups.fetch(group_id),
         {:ok, result} <- ContentPieces.reorder(group, params) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def archive(conn, %{"id" => id} = params) do
    with {:ok, piece} <- ContentPieces.fetch(id),
         {:ok, result} <- ContentPieces.archive(piece, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def unarchive(conn, %{"id" => id} = params) do
    with {:ok, piece} <- ContentPieces.fetch(id),
         {:ok, result} <- ContentPieces.unarchive(piece, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, piece} <- ContentPieces.fetch(id),
         {:ok, result} <- ContentPieces.delete(piece, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: piece, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      content_piece: piece_json(piece),
      differences: differences || %{}
    }
  end

  defp body(%{result: result, record: piece}) do
    %{result: result, content_piece: piece_json(piece)}
  end

  def piece_json(piece) do
    %{
      id: piece.id,
      api_ref: piece.api_ref,
      content_group_id: piece.content_group_id,
      display_order: piece.display_order,
      title: piece.title,
      description: piece.description,
      date_published: piece.date_published,
      length: piece.length,
      file_url: piece.file_url,
      youtube_id: piece.youtube_id,
      media_type: piece.media_type,
      external_id: piece.external_id,
      season: piece.season,
      episode_number: piece.episode_number,
      episode_type: piece.episode_type,
      image: piece.image,
      source_provider: piece.source_provider,
      source_url: piece.source_url,
      archived_at: piece.archived_at
    }
  end
end