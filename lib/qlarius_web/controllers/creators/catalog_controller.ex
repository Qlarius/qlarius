defmodule QlariusWeb.Creators.CatalogController do
  use QlariusWeb, :controller

  alias Qlarius.Creators
  alias Qlarius.Arcade.Catalog

  def new(conn, %{"creator_id" => creator_id}) do
    creator = Creators.get_creator!(creator_id)
    changeset = Creators.change_catalog(%Catalog{}, %{}, conn.assigns.current_scope)
    render(conn, :new, changeset: changeset, creator: creator)
  end

  def create(conn, %{"creator_id" => creator_id, "catalog" => catalog_params}) do
    creator = Creators.get_creator!(creator_id)

    case Creators.create_catalog(conn.assigns.current_scope, catalog_params, creator) do
      {:ok, _catalog} ->
        conn
        |> put_flash(:info, "Catalog created successfully.")
        |> redirect(to: ~p"/creators/#{creator_id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, creator: creator)
    end
  end

  def edit(conn, %{"creator_id" => creator_id, "id" => id}) do
    creator = Creators.get_creator!(creator_id)
    catalog = Creators.get_catalog!(id)
    changeset = Creators.change_catalog(catalog, %{}, conn.assigns.current_scope)
    render(conn, :edit, catalog: catalog, changeset: changeset, creator: creator)
  end

  def update(conn, %{"creator_id" => creator_id, "id" => id, "catalog" => catalog_params}) do
    creator = Creators.get_creator!(creator_id)
    catalog = Creators.get_catalog!(id)

    case Creators.update_catalog(conn.assigns.current_scope, catalog, catalog_params) do
      {:ok, _catalog} ->
        conn
        |> put_flash(:info, "Catalog updated successfully.")
        |> redirect(to: ~p"/creators/#{creator_id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, catalog: catalog, changeset: changeset, creator: creator)
    end
  end

  def delete(conn, %{"creator_id" => creator_id, "id" => id}) do
    catalog = Creators.get_catalog!(id)
    {:ok, _catalog} = Creators.delete_catalog(catalog)

    conn
    |> put_flash(:info, "Catalog deleted successfully.")
    |> redirect(to: ~p"/creators/#{creator_id}")
  end
end
