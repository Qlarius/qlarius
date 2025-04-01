defmodule QlariusWeb.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Arcade
  alias Qlarius.Arcade.Content

  plug :put_new_layout, {QlariusWeb.Layouts, :arcade}

  def index(conn, _params) do
    content = Arcade.list_content()
    render(conn, :index, content_collection: content)
  end

  def new(conn, _params) do
    changeset = Arcade.change_content(%Content{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"content" => content_params}) do
    case Arcade.create_content(content_params) do
      {:ok, content} ->
        conn
        |> put_flash(:info, "Content created successfully.")
        |> redirect(to: ~p"/content/#{content}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    content = Arcade.get_content!(id)
    render(conn, :show, content: content)
  end

  def edit(conn, %{"id" => id}) do
    content = Arcade.get_content!(id)
    changeset = Arcade.change_content(content)
    render(conn, :edit, content: content, changeset: changeset)
  end

  def update(conn, %{"id" => id, "content" => content_params}) do
    content = Arcade.get_content!(id)

    case Arcade.update_content(content, content_params) do
      {:ok, content} ->
        conn
        |> put_flash(:info, "Content updated successfully.")
        |> redirect(to: ~p"/content/#{content}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, content: content, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    content = Arcade.get_content!(id)
    {:ok, _content} = Arcade.delete_content(content)

    conn
    |> put_flash(:info, "Content deleted successfully.")
    |> redirect(to: ~p"/content")
  end
end
