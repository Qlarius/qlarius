defmodule QlariusWeb.Api.Admin.CatalogController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.{Catalogs, Creators, ImageUrls}
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, %{"creator_id" => creator_id}) do
    case Creators.fetch(creator_id) do
      {:ok, creator} ->
        catalogs = Catalogs.list(creator)
        json(conn, %{count: length(catalogs), catalogs: Enum.map(catalogs, &catalog_json/1)})

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    case Catalogs.fetch(id) do
      {:ok, catalog} -> json(conn, %{catalog: catalog_json(catalog)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, %{"creator_id" => creator_id} = params) do
    with {:ok, creator} <- Creators.fetch(creator_id),
         {:ok, result} <- Catalogs.create(creator, params, dry_run: Responder.dry_run?(params)) do
      conn = if result.result == "created", do: put_status(conn, 201), else: conn
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, catalog} <- Catalogs.fetch(id),
         {:ok, result} <- Catalogs.update(catalog, params, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, catalog} <- Catalogs.fetch(id),
         {:ok, result} <- Catalogs.delete(catalog, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: catalog, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      catalog: catalog_json(catalog),
      differences: differences
    }
  end

  def catalog_json(catalog) do
    %{
      id: catalog.id,
      api_ref: catalog.api_ref,
      creator_id: catalog.creator_id,
      recipient_id: catalog.recipient_id,
      name: catalog.name,
      url: catalog.url,
      type: catalog.type,
      group_type: catalog.group_type,
      piece_type: catalog.piece_type,
      image: catalog.image,
      image_url: ImageUrls.content_image_url(catalog),
      tiqit_undo_limit: catalog.tiqit_undo_limit,
      tiqit_up_enabled: catalog.tiqit_up_enabled
    }
  end
end
