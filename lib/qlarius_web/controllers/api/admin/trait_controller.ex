defmodule QlariusWeb.Api.Admin.TraitController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.TraitDesign
  alias Qlarius.YouData.TraitGuards
  alias Qlarius.YouData.TraitManager
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    scope = conn.assigns.current_scope

    parents =
      TraitManager.list_parents(scope,
        q: params["q"] || "",
        category_id: integer(params["category_id"]),
        include_inactive: truthy?(params["include_inactive"])
      )

    json(conn, %{
      traits:
        Enum.map(parents, fn trait ->
          %{
            id: trait.id,
            trait_name: trait.trait_name,
            input_type: trait.input_type,
            is_active: trait.is_active,
            display_order: trait.display_order,
            trait_category_id: trait.trait_category_id
          }
        end)
    })
  end

  def catalog(conn, _params) do
    json(conn, %{trait_categories: Traits.traits_catalog()})
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, trait} <- TraitManager.fetch_trait(scope, id),
         :ok <- parent_only(trait) do
      json(conn, TraitDesign.parent_detail(TraitManager.get_parent_trait_with_details(scope, id)))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    force = truthy?(params["force"])

    with {:ok, trait} <- TraitManager.fetch_trait(scope, id),
         :ok <- parent_only(trait),
         :ok <- TraitGuards.ensure_input_type_change(trait, params["input_type"], force),
         {:ok, _} <- TraitManager.update_parent_trait(scope, trait, parent_attrs(params)) do
      json(conn, TraitDesign.parent_detail(TraitManager.get_parent_trait_with_details(scope, id)))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create_children(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    force = truthy?(params["force"])
    children = params["children"] || []

    with {:ok, parent} <- TraitManager.fetch_trait(scope, id),
         :ok <- no_children_of_children(parent),
         :ok <- TraitGuards.ensure_child_mutation(parent, force),
         {:ok, created} <- insert_children(scope, parent, children) do
      conn
      |> put_status(201)
      |> json(%{
        children:
          Enum.map(created, fn child ->
            %{id: child.id, trait_name: child.trait_name, display_order: child.display_order}
          end)
      })
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update_child(conn, %{"id" => id, "child_id" => child_id} = params) do
    scope = conn.assigns.current_scope
    force = truthy?(params["force"])

    with {:ok, parent} <- TraitManager.fetch_trait(scope, id),
         :ok <- parent_only(parent),
         :ok <- TraitGuards.ensure_child_mutation(parent, force),
         {:ok, child} <- TraitManager.fetch_trait(scope, child_id),
         :ok <- child_of(parent, child),
         {:ok, child} <- TraitManager.update_child_trait(scope, child, child_attrs(params)) do
      json(conn, %{
        id: child.id,
        trait_name: child.trait_name,
        display_order: child.display_order,
        is_active: child.is_active
      })
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def deactivate(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, trait} <- TraitManager.fetch_trait(scope, id),
         {:ok, trait} <- TraitManager.deactivate_trait(scope, trait) do
      json(conn, %{id: trait.id, is_active: trait.is_active})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def design_pack(conn, params) do
    case TraitDesign.apply(conn.assigns.current_scope, params) do
      {:ok, detail} -> json(conn, detail)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp insert_children(scope, parent, children) when is_list(children) and children != [] do
    Enum.reduce_while(children, {:ok, []}, fn child, {:ok, acc} ->
      name = child["trait_name"]

      cond do
        name in [nil, ""] or
            (is_binary(name) and (String.trim(name) == "" or String.length(name) > 256)) ->
          {:halt, {:error, :invalid_trait_name}}

        true ->
          case TraitManager.create_child_trait(scope, parent, %{
                 "trait_name" => String.trim(name),
                 "display_order" => integer(child["display_order"])
               }) do
            {:ok, created} -> {:cont, {:ok, acc ++ [created]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
  end

  defp insert_children(_scope, _parent, _), do: {:error, :empty_pack}

  defp parent_only(%{parent_trait_id: nil}), do: :ok
  defp parent_only(_), do: {:error, :not_a_parent}

  defp no_children_of_children(%{parent_trait_id: nil}), do: :ok
  defp no_children_of_children(_), do: {:error, :child_under_child}

  defp child_of(parent, %{parent_trait_id: parent_id}) when parent_id == parent.id, do: :ok
  defp child_of(_, _), do: {:error, :child_not_in_parent}

  defp parent_attrs(params) do
    params
    |> Map.take(["trait_name", "input_type", "trait_category_id", "display_order", "is_active"])
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Map.new()
  end

  defp child_attrs(params) do
    params
    |> Map.take(["trait_name", "display_order", "is_active"])
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Map.new()
  end

  defp truthy?(value), do: value in [true, "true", "1", 1]

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil
end
