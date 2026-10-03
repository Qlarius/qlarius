defmodule QlariusWeb.Api.Admin.TraitGroupController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.TraitGroups
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    groups = TraitGroups.list(params)
    json(conn, %{count: length(groups), trait_groups: Enum.map(groups, &group_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case TraitGroups.fetch(id) do
      {:ok, group} -> json(conn, %{trait_group: group_json(group)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case TraitGroups.create(params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(body(result))
      {:ok, result} -> json(conn, body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, group} <- TraitGroups.fetch(id),
         {:ok, result} <- TraitGroups.update(group, params, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def traits(conn, %{"id" => id} = params) do
    with {:ok, group} <- TraitGroups.fetch(id),
         {:ok, result} <-
           TraitGroups.change_traits(group, params, dry_run: Responder.dry_run?(params)) do
      json(conn, %{
        result: result.result,
        trait_group: result |> Map.get(:record) |> group_json(),
        trait_ids: result[:trait_ids]
      })
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, group} <- TraitGroups.fetch(id),
         {:ok, result} <- TraitGroups.delete(group, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: group, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      trait_group: group_json(group),
      differences: differences
    }
  end

  defp group_json(nil), do: nil

  defp group_json(%{id: id} = group) when is_integer(id) do
    group |> Qlarius.Repo.preload(:traits) |> group_fields()
  end

  defp group_json(group), do: group_fields(group)

  defp group_fields(group) do
    %{
      id: group.id,
      api_ref: group.api_ref,
      title: group.title,
      description: group.description,
      parent_trait_id: group.parent_trait_id,
      marketer_id: group.marketer_id,
      creator_id: group.creator_id,
      deactivated_at: group.deactivated_at,
      me_file_count: Map.get(group, :me_file_count),
      trait_ids: group |> Map.get(:traits, []) |> Enum.map(& &1.id)
    }
  end
end
