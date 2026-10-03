defmodule QlariusWeb.Api.Admin.TargetController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.Targets
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.Target
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    targets = Targets.list(params)
    json(conn, %{count: length(targets), targets: Enum.map(targets, &summary/1)})
  end

  def show(conn, %{"id" => id}) do
    case Targets.fetch(id) do
      {:ok, target} -> json(conn, %{target: target})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def build(conn, params) do
    case Targets.build(conn.assigns.current_scope, params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(result)
      {:ok, result} -> json(conn, result)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def add_band(conn, %{"id" => id} = params) do
    with {:ok, target} <- load(id),
         {:ok, band} <- Targets.add_band(target, params["exclude_trait_group_id"]) do
      json(conn, %{result: "created", band_id: band.id})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete_outermost(conn, %{"id" => id}) do
    with {:ok, target} <- load(id),
         {:ok, _} <- Targets.delete_outermost(target) do
      json(conn, %{result: "deleted"})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def clone(conn, %{"id" => id} = params) do
    with {:ok, target} <- load(id),
         {:ok, clone} <- Targets.clone(conn.assigns.current_scope, target, params) do
      conn |> put_status(201) |> json(%{target: clone})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def populate(conn, %{"id" => id}) do
    with {:ok, target} <- load(id),
         :ok <- Targets.populate(target) do
      json(conn, %{result: "populating", population_status: "populating", target_id: target.id})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def population(conn, %{"id" => id}) do
    with {:ok, target} <- load(id) do
      json(conn, Targets.population(target))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, target} <- load(id),
         {:ok, result} <- Targets.delete(target, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp load(id) do
    case Repo.get(Target, id) do
      nil -> {:error, :not_found}
      target -> {:ok, target}
    end
  end

  defp summary(target) do
    Map.take(target, [
      :id,
      :api_ref,
      :title,
      :marketer_id,
      :creator_id,
      :population_status,
      :archived_at
    ])
  end
end
