defmodule QlariusWeb.Api.Admin.YoutubeImportController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.YoutubeImports
  alias Qlarius.Tiqit.Arcade.ContentPack
  alias QlariusWeb.Api.Admin.Responder

  def preview(conn, params) do
    case YoutubeImports.preview(params["input"]) do
      {:ok, fetched} ->
        preview = fetched.channel_preview

        json(conn, %{
          import_kind: preview.import_kind,
          title: preview.title,
          description: preview.description,
          videos:
            Enum.map(fetched.videos, fn video ->
              %{
                youtube_id: video.youtube_id,
                title: video.title,
                description: video.description,
                length: video.length,
                date_published: video.date_published
              }
            end)
        })

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case YoutubeImports.import(params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(body(result))
      {:ok, result} -> json(conn, body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: group, differences: differences, pieces: pieces}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      content_group: ContentPack.group_json(group),
      differences: differences,
      pieces: pieces
    }
  end
end