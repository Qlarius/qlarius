defmodule QlariusWeb.Creators.ContentGroupController do
  use QlariusWeb, :controller

  alias Qlarius.Creators
  alias Qlarius.Arcade.ContentGroup

  def index(conn, _params) do
    content_groups = Creators.list_content_groups(conn.assigns.current_scope)
    render(conn, :index, content_groups: content_groups)
  end

  def new(conn, _params) do
    changeset = Creators.change_content_group(%ContentGroup{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"content_group" => content_group_params}) do
    case Creators.create_content_group(conn.assigns.current_scope, content_group_params) do
      {:ok, content_group} ->
        conn
        |> put_flash(:info, "Group created successfully.")
        |> redirect(to: ~p"/creators/content_groups/#{content_group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    content_group = Creators.get_content_group!(conn.assigns.current_scope, id)
    render(conn, :show, content_group: content_group)
  end

  def edit(conn, %{"id" => id}) do
    content_group = Creators.get_content_group!(conn.assigns.current_scope, id)
    changeset = Creators.change_content_group(content_group)
    render(conn, :edit, content_group: content_group, changeset: changeset)
  end

  def update(conn, %{"id" => id, "content_group" => content_group_params}) do
    content_group = Creators.get_content_group!(conn.assigns.current_scope, id)

    case Creators.update_content_group(
           conn.assigns.current_scope,
           content_group,
           content_group_params
         ) do
      {:ok, content_group} ->
        conn
        |> put_flash(:info, "Content group updated successfully.")
        |> redirect(to: ~p"/creators/content_groups/#{content_group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, content_group: content_group, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    content_group = Creators.get_content_group!(conn.assigns.current_scope, id)

    {:ok, _content_group} =
      Creators.delete_content_group(conn.assigns.current_scope, content_group)

    conn
    |> put_flash(:info, "Content group deleted successfully.")
    |> redirect(to: ~p"/creators/content_groups")
  end
end
