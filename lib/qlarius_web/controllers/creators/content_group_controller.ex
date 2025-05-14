defmodule QlariusWeb.Creators.ContentGroupController do
  use QlariusWeb, :controller

  alias Qlarius.Creators
  alias Qlarius.Arcade.ContentGroup

  def new(conn, %{"catalog_id" => catalog_id}) do
    catalog = Creators.get_catalog!(catalog_id)
    changeset = Creators.change_content_group(%ContentGroup{catalog: catalog})
    render(conn, :new, catalog: catalog, changeset: changeset, creator: catalog.creator)
  end

  def create(conn, %{"catalog_id" => catalog_id, "content_group" => content_group_params}) do
    catalog = Creators.get_catalog!(catalog_id)

    case Creators.create_content_group(catalog, content_group_params) do
      {:ok, content_group} ->
        conn
        |> put_flash(:info, "Group created successfully.")
        |> redirect(to: ~p"/creators/content_groups/#{content_group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    content_group = Creators.get_content_group!(id)
    catalog = content_group.catalog
    creator = catalog.creator
    render(conn, :show, catalog: catalog, creator: creator, content_group: content_group)
  end

  def edit(conn, %{"id" => id}) do
    content_group = Creators.get_content_group!(id)
    changeset = Creators.change_content_group(content_group)
    catalog = content_group.catalog
    creator = catalog.creator

    render(conn, :edit,
      catalog: catalog,
      creator: creator,
      content_group: content_group,
      changeset: changeset
    )
  end

  def update(conn, %{"id" => id, "content_group" => content_group_params}) do
    content_group = Creators.get_content_group!(id)

    case Creators.update_content_group(content_group, content_group_params) do
      {:ok, content_group} ->
        conn
        |> put_flash(:info, "Content group updated successfully.")
        |> redirect(to: ~p"/creators/content_groups/#{content_group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, content_group: content_group, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    content_group = Creators.get_content_group!(id)
    catalog = content_group.catalog

    {:ok, _content_group} =
      Creators.delete_content_group(content_group)

    conn
    |> put_flash(:info, "Delete content group")
    |> redirect(to: ~p"/creators/catalogs/#{catalog}")
  end
end
