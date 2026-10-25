defmodule QlariusWeb.Api.Admin.TraitRelationshipController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.TraitRelationships
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    kind = params["type"] || params["kind"]
    direction = params["direction"]

    cond do
      direction not in [nil, "", "from", "to"] ->
        Responder.error(conn, :invalid_direction)

      parent_id = integer(params["parent_id"]) ->
        relationships =
          parent_id
          |> TraitRelationships.list_among_children(kind)
          |> Enum.map(&TraitRelationships.to_json/1)

        json(conn, %{relationships: relationships})

      trait_id = integer(params["trait_id"]) ->
        relationships =
          trait_id
          |> TraitRelationships.list_for_parent(kind, direction)
          |> Enum.map(&TraitRelationships.to_json/1)

        json(conn, %{relationships: relationships})

      true ->
        Responder.error(conn, :trait_id_required)
    end
  end

  def create(conn, params) do
    attrs =
      %{
        "trait_id" => params["trait_id"],
        "related_trait_id" => params["related_trait_id"],
        "kind" => params["kind"] || params["type"],
        "note" => params["note"]
      }
      |> put_severity(params)

    case TraitRelationships.create(attrs) do
      {:ok, relationship} ->
        conn
        |> put_status(201)
        |> json(%{
          relationship: TraitRelationships.to_json(relationship),
          warnings: TraitRelationships.warnings(relationship)
        })

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def bulk(conn, params) do
    case TraitRelationships.bulk(params) do
      {:ok, body} ->
        json(conn, body)

      {:error, :too_many_operations} ->
        Responder.error(conn, :too_many_operations)

      {:error, :invalid_payload} ->
        Responder.error(conn, :invalid_payload)

      {:error, body} ->
        conn |> put_status(422) |> json(Map.put(body, :error, "invalid"))
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs =
      %{}
      |> put_present("note", params)
      |> put_kind(params)
      |> put_severity(params)

    case TraitRelationships.get(id) do
      nil ->
        Responder.error(conn, :not_found)

      relationship ->
        case TraitRelationships.update(relationship, attrs) do
          {:ok, relationship} ->
            json(conn, %{
              relationship: TraitRelationships.to_json(relationship),
              warnings: TraitRelationships.warnings(relationship)
            })

          {:error, reason} ->
            Responder.error(conn, reason)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case TraitRelationships.get(id) do
      nil ->
        Responder.error(conn, :not_found)

      relationship ->
        {:ok, _} = TraitRelationships.delete(relationship)
        json(conn, %{deleted: true})
    end
  end

  defp put_present(attrs, key, params) do
    if Map.has_key?(params, key), do: Map.put(attrs, key, params[key]), else: attrs
  end

  defp put_kind(attrs, params) do
    kind = params["type"] || params["kind"]
    if kind in [nil, ""], do: attrs, else: Map.put(attrs, "kind", kind)
  end

  defp put_severity(attrs, params) do
    case params["severity"] do
      severity when severity in [nil, ""] -> attrs
      severity -> Map.put(attrs, "severity", severity)
    end
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil
end
