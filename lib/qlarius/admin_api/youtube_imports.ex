defmodule Qlarius.AdminApi.YoutubeImports do
  @moduledoc """
  YouTube preview and import through `Qlarius.Youtube.Client`.

  A group is found or created by `api_ref`. Pieces already stored under
  that group with the same `external_id` (the video id) are left as they
  are. `feed_auto_sync` stays off unless the request sets it.
  """

  import Ecto.Query

  alias Qlarius.AdminApi.{Idempotent, Params, Prices}
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Arcade, Catalog, ContentGroup, ContentPiece, YoutubeImporter}

  def preview(input) when is_binary(input) and input != "" do
    case YoutubeImporter.fetch_import_preview(input) do
      {:ok, fetched} -> {:ok, fetched}
      {:error, reason} -> {:error, reason}
    end
  rescue
    exception in RuntimeError ->
      if Exception.message(exception) =~ "YOUTUBE_DATA_API_KEY" do
        {:error, :youtube_unavailable}
      else
        reraise exception, __STACKTRACE__
      end
  end

  def preview(_), do: {:error, :input_required}

  def import(params, opts) do
    with :ok <- Prices.reject(params),
         {:ok, catalog} <- fetch_catalog(params["catalog_id"]),
         {:ok, fetched} <- preview(params["input"]) do
      title = fetched.channel_preview.title
      description = fetched.channel_preview.description

      group_params =
        params
        |> Map.put("title", params["title"] || title)
        |> Map.put("description", params["description"] || description)

      case Idempotent.create(ContentGroup, group_params,
             fields: ~w(title description),
             dry_run: opts[:dry_run],
             on_existing: params["on_existing"],
             owned?: &(&1.catalog_id == catalog.id),
             preview: fn attrs ->
               cs =
                 %ContentGroup{catalog_id: catalog.id}
                 |> ContentGroup.import_changeset(group_attrs(catalog, attrs, params["input"]))

               if cs.valid?, do: {:ok, Ecto.Changeset.apply_changes(cs)}, else: {:error, cs}
             end,
             insert: fn _ ->
               insert_group(catalog, group_params, params["input"])
             end,
             update: fn group, attrs ->
               group
               |> ContentGroup.import_changeset(Map.take(attrs, ~w(title description)))
               |> Repo.update()
             end
           ) do
        {:ok, %{result: result, record: group} = outcome} ->
          pieces = pieces(group, fetched.videos, result, opts[:dry_run])
          {:ok, Map.put(outcome, :pieces, pieces)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp pieces(_group, videos, "would_create", _dry) do
    Enum.map(videos, &%{external_id: &1.youtube_id, title: &1.title, result: "would_create"})
  end

  defp pieces(group, videos, _result, true) do
    existing = existing_ids(group)

    Enum.map(videos, fn video ->
      result = if MapSet.member?(existing, video.youtube_id), do: "matched", else: "would_create"
      %{external_id: video.youtube_id, title: video.title, result: result}
    end)
  end

  defp pieces(group, videos, _result, false) do
    existing = existing_ids(group)
    fresh = Enum.reject(videos, &MapSet.member?(existing, &1.youtube_id))

    {:ok, imported} = YoutubeImporter.import_into_group(group, fresh)

    matched =
      videos
      |> Enum.filter(&MapSet.member?(existing, &1.youtube_id))
      |> Enum.map(&%{external_id: &1.youtube_id, title: &1.title, result: "matched"})

    created =
      Enum.map(imported, fn %{video: video, status: status} ->
        %{
          external_id: video.youtube_id,
          title: video.title,
          result: if(status == :ok, do: "created", else: "error"),
          error: if(status == :ok, do: nil, else: elem(status, 1))
        }
      end)

    matched ++ created
  end

  defp existing_ids(%ContentGroup{id: nil}), do: MapSet.new()

  defp existing_ids(%ContentGroup{id: id}) do
    Repo.all(
      from p in ContentPiece,
        where: p.content_group_id == ^id and not is_nil(p.external_id),
        select: p.external_id
    )
    |> MapSet.new()
  end

  defp insert_group(catalog, params, input) do
    Repo.transaction(fn ->
      with {:ok, group} <-
             %ContentGroup{catalog_id: catalog.id, catalog: catalog}
             |> ContentGroup.import_changeset(group_attrs(catalog, params, input))
             |> Repo.insert() do
        Arcade.write_default_group_tiqit_classes(group)
        %{group | catalog: catalog}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp group_attrs(_catalog, params, input) do
    %{
      title: params["title"],
      description: params["description"],
      source_provider: "youtube",
      source_url: input,
      api_ref: params["api_ref"],
      feed_auto_sync: params["feed_auto_sync"] in [true, "true", "1"]
    }
  end

  defp fetch_catalog(id) do
    case Params.integer(id) do
      nil ->
        {:error, :catalog_not_found}

      id ->
        case Repo.get(Catalog, id) do
          nil -> {:error, :catalog_not_found}
          catalog -> {:ok, catalog}
        end
    end
  end
end