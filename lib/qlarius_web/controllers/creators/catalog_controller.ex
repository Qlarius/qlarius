defmodule QlariusWeb.Creators.CatalogController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Catalog

  def show(conn, %{"id" => id}) do
    catalog = Creators.get_catalog!(id)
    creator = catalog.creator

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator}"},
      {catalog.name, nil}
    ]

    render(conn, :show, catalog: catalog, creator: creator, breadcrumbs: breadcrumbs)
  end

  def add_default_tiqit_classes(conn, %{"catalog_id" => catalog_id}) do
    catalog = Creators.get_catalog!(catalog_id)

    # Call the arcade context function
    Qlarius.Tiqit.Arcade.Arcade.write_default_catalog_tiqit_classes(catalog)

    conn
    |> put_flash(:info, "Default Tiqit classes added successfully.")
    |> redirect(to: ~p"/creators/catalogs/#{catalog}")
  end

  def new(conn, %{"creator_id" => creator_id}) do
    creator = Creators.get_creator!(creator_id)
    changeset = Creators.change_catalog(%Catalog{})
    render(conn, :new, changeset: changeset, creator: creator)
  end

  def create(conn, %{"creator_id" => creator_id, "catalog" => catalog_params}) do
    creator = Creators.get_creator!(creator_id)

    case Creators.create_catalog(creator, catalog_params) do
      {:ok, catalog} ->
        conn
        |> put_flash(:info, "Catalog created successfully.")
        |> redirect(to: ~p"/creators/catalogs/#{catalog}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, creator: creator)
    end
  end

  def edit(conn, %{"id" => id}) do
    catalog = Creators.get_catalog!(id)
    creator = catalog.creator
    changeset = Creators.change_catalog(catalog)
    render(conn, :edit, catalog: catalog, changeset: changeset, creator: creator)
  end

  def update(conn, %{"id" => id, "catalog" => catalog_params}) do
    catalog = Creators.get_catalog!(id)
    creator = catalog.creator

    case Creators.update_catalog(catalog, catalog_params) do
      {:ok, catalog} ->
        conn
        |> put_flash(:info, "Catalog updated successfully.")
        |> redirect(to: ~p"/creators/catalogs/#{catalog}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, catalog: catalog, changeset: changeset, creator: creator)
    end
  end

  def delete(conn, %{"id" => id}) do
    catalog = Creators.get_catalog!(id)
    creator = catalog.creator
    {:ok, _catalog} = Creators.delete_catalog(catalog)

    conn
    |> put_flash(:info, "Catalog deleted successfully.")
    |> redirect(to: ~p"/creators/#{creator}")
  end
end
