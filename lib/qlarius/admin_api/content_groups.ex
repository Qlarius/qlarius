defmodule Qlarius.AdminApi.ContentGroups do
  import Ecto.Query

  alias Qlarius.AdminApi.{Idempotent, Params, Prices, RemoteImage}
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Arcade, Catalog, ContentGroup, ContentPiece}

  @fields ~w(title description show_piece_thumbnails show_piece_descriptions show_open_in_tab source_provider source_url feed_url feed_season feed_episode_types feed_auto_sync)

  def fetch(id) do
    case Params.integer(id) do
      nil ->
        {:error, :not_found}

      id ->
        case Repo.get(ContentGroup, id) do
          nil -> {:error, :not_found}
          group -> {:ok, Repo.preload(group, :catalog)}
        end
    end
  end

  def create(%Catalog{} = catalog, params, opts) do
    with :ok <- Prices.reject(params) do
      Idempotent.create(ContentGroup, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        owned?: &(&1.catalog_id == catalog.id),
        preview: &preview/1,
        insert: fn _ -> insert(catalog, params) end,
        update: fn group, _attrs -> save(group, params) end
      )
    end
  end

  def update(%ContentGroup{} = group, params, opts) do
    with :ok <- Prices.reject(params),
         :ok <- immutable?(group, params),
         :ok <- RemoteImage.validate(params["image_url"]) do
      differences =
        group
        |> Idempotent.differences(params, @fields)
        |> Map.merge(RemoteImage.difference(group, params))

      if opts[:dry_run] do
        case changeset(group, params) do
          %{valid?: true} ->
            {:ok, %{result: "would_update", record: group, differences: differences}}

          changeset ->
            {:error, changeset}
        end
      else
        with {:ok, updated} <- save(group, params) do
          {:ok, %{result: "updated", record: updated, differences: differences}}
        end
      end
    end
  end

  def delete(%ContentGroup{} = group, opts) do
    dependents = dependents(group.id)

    cond do
      Enum.any?(dependents, fn {_key, count} -> count > 0 end) ->
        {:error, {:has_dependents, dependents}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{content_group: group.id}}}

      true ->
        case Repo.delete(group) do
          {:ok, _} -> {:ok, %{result: "deleted", removes: %{content_group: group.id}}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def dependents(group_id) do
    %{
      content_pieces:
        Repo.aggregate(from(p in ContentPiece, where: p.content_group_id == ^group_id), :count)
    }
  end

  defp preview(params) do
    cs = changeset(%ContentGroup{}, params)

    with :ok <- RemoteImage.validate(params["image_url"]),
         true <- cs.valid? || {:error, cs} do
      {:ok, Ecto.Changeset.apply_changes(cs)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert(catalog, params) do
    Repo.transaction(fn ->
      with {:ok, group} <-
             %ContentGroup{catalog_id: catalog.id, catalog: catalog}
             |> changeset(Map.put(params, "api_ref", params["api_ref"]))
             |> Repo.insert(),
           {:ok, group} <- maybe_image(group, params["image_url"]) do
        Arcade.write_default_group_tiqit_classes(group)
        %{group | catalog: catalog}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp save(group, params) do
    group = Repo.preload(group, :catalog)

    Repo.transaction(fn ->
      with {:ok, group} <- group |> changeset(params) |> Repo.update(),
           {:ok, group} <- maybe_image(%{group | catalog: group.catalog}, params["image_url"]) do
        group
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp changeset(group, params) do
    group
    |> ContentGroup.import_changeset(params)
    |> Ecto.Changeset.cast(params, [
      :show_piece_thumbnails,
      :show_piece_descriptions,
      :show_open_in_tab
    ])
  end

  defp maybe_image(group, url) when is_binary(url) and url != "" do
    RemoteImage.assign(group, url, "group-#{group.id}")
  end

  defp maybe_image(group, _), do: {:ok, group}

  defp immutable?(group, params) do
    if Map.has_key?(params, "api_ref") and params["api_ref"] != group.api_ref do
      {:error, :api_ref_immutable}
    else
      :ok
    end
  end
end
