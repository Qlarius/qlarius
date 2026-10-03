defmodule QlariusWeb.Api.Admin.MediaPieceController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.MediaPieces
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    pieces = MediaPieces.list(params)
    json(conn, %{count: length(pieces), media_pieces: Enum.map(pieces, &piece_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case MediaPieces.fetch(id) do
      {:ok, piece} -> json(conn, %{media_piece: piece_json(piece)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case MediaPieces.create(params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(result_body(result))
      {:ok, result} -> json(conn, result_body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, piece} <- MediaPieces.fetch(id),
         {:ok, result} <- MediaPieces.update(piece, params, dry_run: Responder.dry_run?(params)) do
      json(conn, result_body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, piece} <- MediaPieces.fetch(id),
         {:ok, result} <- MediaPieces.delete(piece, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp result_body(%{result: result, record: piece, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      media_piece: piece_json(piece),
      differences: differences
    }
  end

  defp piece_json(piece) do
    %{
      id: piece.id,
      api_ref: piece.api_ref,
      marketer_id: piece.marketer_id,
      media_piece_type_id: piece.media_piece_type_id,
      media_piece_type: type_name(piece),
      ad_category_id: piece.ad_category_id,
      ad_category_row_id: category_row(piece),
      title: piece.title,
      body_copy: piece.body_copy,
      display_url: piece.display_url,
      jump_url: piece.jump_url,
      active: piece.active,
      duration: piece.duration,
      banner_image: piece.banner_image,
      banner_url: banner_url(piece)
    }
  end

  defp banner_url(%{banner_image: name}) when is_binary(name) and name != "" do
    QlariusWeb.Uploaders.ThreeTapBanner.url({name, nil}, :original)
  end

  defp banner_url(_), do: nil

  defp type_name(%{media_piece_type: %{name: name}}), do: name
  defp type_name(_), do: nil

  defp category_row(%{ad_category: %{row_id: row_id}}), do: row_id
  defp category_row(_), do: nil
end
