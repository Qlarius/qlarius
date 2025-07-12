defmodule QlariusWeb.Admin.MarketerController do
  use QlariusWeb, :controller

  alias Qlarius.Accounts.Marketers

  def index(conn, _params) do
    marketers = Marketers.list_marketers(conn.assigns.current_scope)
    render(conn, :index, marketers: marketers)
  end

  def new(conn, _params) do
    changeset = Marketers.change_marketer(conn.assigns.current_scope)
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"marketer" => marketer_params}) do
    case Marketers.create_marketer(conn.assigns.current_scope, marketer_params) do
      {:ok, marketer} ->
        conn
        |> put_flash(:info, "Marketer created successfully.")
        |> redirect(to: ~p"/marketers/#{marketer}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    marketer = Marketers.get_marketer!(conn.assigns.current_scope, id)
    render(conn, :show, marketer: marketer)
  end

  def edit(conn, %{"id" => id}) do
    marketer = Marketers.get_marketer!(conn.assigns.current_scope, id)
    changeset = Marketers.change_marketer(conn.assigns.current_scope, marketer)
    render(conn, :edit, marketer: marketer, changeset: changeset)
  end

  def update(conn, %{"id" => id, "marketer" => marketer_params}) do
    marketer = Marketers.get_marketer!(conn.assigns.current_scope, id)

    case Marketers.update_marketer(conn.assigns.current_scope, marketer, marketer_params) do
      {:ok, marketer} ->
        conn
        |> put_flash(:info, "Marketer updated successfully.")
        |> redirect(to: ~p"/marketers/#{marketer}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, marketer: marketer, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    marketer = Marketers.get_marketer!(conn.assigns.current_scope, id)
    {:ok, _marketer} = Marketers.delete_marketer(conn.assigns.current_scope, marketer)

    conn
    |> put_flash(:info, "Marketer deleted successfully.")
    |> redirect(to: ~p"/marketers")
  end
end
