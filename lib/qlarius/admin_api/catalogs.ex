defmodule Qlarius.AdminApi.Catalogs do
  import Ecto.Query

  alias Qlarius.AdminApi.{Idempotent, Params, Prices}
  alias Qlarius.Creators.Creator
  alias Qlarius.Repo

  alias Qlarius.Tiqit.Arcade.{
    Arcade,
    Catalog,
    ContentGroup,
    ContentPiece,
    ImportHttp,
    ImportImage
  }

  @fields ~w(name url type group_type piece_type tiqit_undo_limit tiqit_up_enabled recipient_id)

  def list(%Creator{} = creator) do
    Repo.all(from c in Catalog, where: c.creator_id == ^creator.id, order_by: [asc: c.name])
  end

  def fetch(id) do
    case Params.integer(id) do
      nil ->
        {:error, :not_found}

      id ->
        case Repo.get(Catalog, id) do
          nil -> {:error, :not_found}
          catalog -> {:ok, catalog}
        end
    end
  end

  def create(%Creator{} = creator, params, opts) do
    with :ok <- Prices.reject(params) do
      Idempotent.create(Catalog, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        owned?: &(&1.creator_id == creator.id),
        preview: &preview(creator, &1),
        insert: fn _ -> insert(creator, params) end,
        update: fn catalog, _attrs -> save(catalog, params) end
      )
    end
  end

  def update(%Catalog{} = catalog, params, opts) do
    with :ok <- Prices.reject(params),
         :ok <- immutable?(catalog, params) do
      differences = Idempotent.differences(catalog, params, @fields)

      if opts[:dry_run] do
        case preview_changeset(catalog, params) do
          {:ok, _} -> {:ok, %{result: "would_update", record: catalog, differences: differences}}
          {:error, reason} -> {:error, reason}
        end
      else
        with {:ok, updated} <- save(catalog, params) do
          {:ok, %{result: "updated", record: updated, differences: differences}}
        end
      end
    end
  end

  def delete(%Catalog{} = catalog, opts) do
    dependents = dependents(catalog.id)

    cond do
      Enum.any?(dependents, fn {_key, count} -> count > 0 end) ->
        {:error, {:has_dependents, dependents}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{catalog: catalog.id}}}

      true ->
        case Repo.delete(catalog) do
          {:ok, _} -> {:ok, %{result: "deleted", removes: %{catalog: catalog.id}}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def dependents(catalog_id) do
    %{
      content_groups:
        Repo.aggregate(from(g in ContentGroup, where: g.catalog_id == ^catalog_id), :count),
      content_pieces:
        Repo.aggregate(
          from(p in ContentPiece,
            join: g in assoc(p, :content_group),
            where: g.catalog_id == ^catalog_id
          ),
          :count
        )
    }
  end

  defp preview(creator, params) do
    with :ok <- image_url(params["image_url"]),
         {:ok, changeset} <- preview_changeset(%Catalog{creator_id: creator.id}, params) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end
  end

  defp preview_changeset(catalog, params) do
    changeset = Catalog.changeset(catalog, Map.take(params, ["api_ref" | @fields]))

    if changeset.valid?, do: {:ok, changeset}, else: {:error, changeset}
  end

  defp insert(creator, params) do
    Repo.transaction(fn ->
      with {:ok, catalog} <-
             %Catalog{creator_id: creator.id}
             |> Catalog.changeset(Map.take(params, ["api_ref" | @fields]))
             |> Repo.insert(),
           {:ok, catalog} <- maybe_image(catalog, params["image_url"]) do
        Arcade.write_default_catalog_tiqit_classes(catalog)
        catalog
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp save(catalog, params) do
    Repo.transaction(fn ->
      with {:ok, catalog} <-
             catalog |> Catalog.changeset(Map.take(params, @fields)) |> Repo.update(),
           {:ok, catalog} <- maybe_image(catalog, params["image_url"]) do
        catalog
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp maybe_image(catalog, url) when is_binary(url) and url != "" do
    with :ok <- image_url(url),
         {:ok, filename} <- ImportImage.store(url, catalog, "catalog-#{catalog.id}") do
      case filename do
        nil -> {:ok, catalog}
        filename -> catalog |> Ecto.Changeset.change(%{image: filename}) |> Repo.update()
      end
    end
  end

  defp maybe_image(catalog, _), do: {:ok, catalog}

  defp immutable?(catalog, params) do
    if Map.has_key?(params, "api_ref") and params["api_ref"] != catalog.api_ref do
      {:error, :api_ref_immutable}
    else
      :ok
    end
  end

  defp image_url(nil), do: :ok
  defp image_url(""), do: :ok

  defp image_url(url) do
    if ImportHttp.public_url?(url, ["https"]), do: :ok, else: {:error, "Image URL must be https"}
  end
end
