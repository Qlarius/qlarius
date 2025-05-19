defmodule QlariusWeb.TargetController do
  use QlariusWeb, :controller

  alias Qlarius.Campaigns
  alias Qlarius.Campaigns.Target

  def index(conn, _params) do
    targets = Campaigns.list_targets()
    render(conn, :index, targets: targets)
  end

  def new(conn, _params) do
    changeset = Campaigns.change_target(%Target{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"target" => target_params}) do
    case Campaigns.create_target(target_params) do
      {:ok, _target} ->
        conn
        |> put_flash(:info, "Target created successfully.")
        |> redirect(to: ~p"/targets")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    target = Campaigns.get_target!(id)
    changeset = Campaigns.change_target(target)
    render(conn, :edit, target: target, changeset: changeset)
  end

  def update(conn, %{"id" => id, "target" => target_params}) do
    target = Campaigns.get_target!(id)

    case Campaigns.update_target(target, target_params) do
      {:ok, _target} ->
        conn
        |> put_flash(:info, "Target updated successfully.")
        |> redirect(to: ~p"/targets")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, target: target, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    target = Campaigns.get_target!(id)
    {:ok, _target} = Campaigns.delete_target(target)

    conn
    |> put_flash(:info, "Target deleted successfully.")
    |> redirect(to: ~p"/targets")
  end
end
