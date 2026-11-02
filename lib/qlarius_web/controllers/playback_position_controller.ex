defmodule QlariusWeb.PlaybackPositionController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.PlaybackPositions

  def create(conn, params) do
    case PlaybackPositions.save_from_token(params) do
      :ok ->
        send_resp(conn, 204, "")

      {:error, :unauthorized} ->
        conn |> put_status(401) |> json(%{error: "unauthorized"})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "invalid"})
    end
  end
end
