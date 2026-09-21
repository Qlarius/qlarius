defmodule QlariusWeb.Api.Admin.TraitCategoryController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.TraitManager
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, _params) do
    categories =
      TraitManager.list_trait_categories(conn.assigns.current_scope)
      |> Enum.map(&%{id: &1.id, name: &1.name, display_order: &1.display_order})

    json(conn, %{trait_categories: categories})
  end

  def create(conn, params) do
    scope = conn.assigns.current_scope

    case TraitManager.create_trait_category(scope, params) do
      {:ok, category} ->
        conn
        |> put_status(201)
        |> json(%{id: category.id, name: category.name, display_order: category.display_order})

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, category} <- TraitManager.get_trait_category(scope, id),
         {:ok, category} <- TraitManager.update_trait_category(scope, category, params) do
      json(conn, %{id: category.id, name: category.name, display_order: category.display_order})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end
end
