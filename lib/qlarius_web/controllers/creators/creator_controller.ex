defmodule QlariusWeb.Creators.CreatorController do
  use QlariusWeb, :controller

  alias Qlarius.Creators
  alias Qlarius.Arcade.Creator

  def index(conn, _params) do
    creators = Creators.list_creators()
    render(conn, :index, creators: creators)
  end

  def new(conn, _params) do
    changeset = Creators.change_creator(%Creator{}, %{}, conn.assigns.current_scope)
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"creator" => creator_params}) do
    case Creators.create_creator(conn.assigns.current_scope, creator_params) do
      {:ok, _creator} ->
        conn
        |> put_flash(:info, "Creator created successfully.")
        |> redirect(to: ~p"/creators")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    creator = Creators.get_creator!(id)
    render(conn, :show, creator: creator)
  end

  def edit(conn, %{"id" => id}) do
    creator = Creators.get_creator!(id)
    changeset = Creators.change_creator(creator, %{}, conn.assigns.current_scope)
    render(conn, :edit, creator: creator, changeset: changeset)
  end

  def update(conn, %{"id" => id, "creator" => creator_params}) do
    creator = Creators.get_creator!(id)

    case Creators.update_creator(conn.assigns.current_scope, creator, creator_params) do
      {:ok, _creator} ->
        conn
        |> put_flash(:info, "Creator updated successfully.")
        |> redirect(to: ~p"/creators")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, creator: creator, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    creator = Creators.get_creator!(id)
    {:ok, _creator} = Creators.delete_creator(creator)

    conn
    |> put_flash(:info, "Creator deleted successfully.")
    |> redirect(to: ~p"/creators")
  end
end
