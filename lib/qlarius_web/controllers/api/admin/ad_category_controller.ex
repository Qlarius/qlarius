defmodule QlariusWeb.Api.Admin.AdCategoryController do
  use QlariusWeb, :controller

  alias Qlarius.Sponster.Ads.{AdCategories, AdCategory}
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    rows = AdCategories.list_rows(Map.take(params, ~w(q category_id cohort active)))

    json(conn, %{
      count: length(rows),
      categories:
        Enum.map(AdCategories.group_rows(rows), fn group ->
          group
          |> Map.take([:category_id, :category_name, :category_label])
          |> Map.put(:rows, Enum.map(group.rows, &row_json/1))
        end),
      attribution: AdCategories.iab_attribution()
    })
  end

  def cohorts(conn, _params) do
    json(conn, %{cohorts: AdCategories.list_cohorts()})
  end

  def create(conn, params) do
    case AdCategories.create_row(params) do
      {:ok, row} ->
        conn
        |> put_status(201)
        |> json(%{row: row_json(row), cohort: row.cohort})

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def update(conn, %{"row_id" => row_id} = params) do
    with {:ok, row} <- fetch(row_id),
         {:ok, row} <- AdCategories.update_row(row, Map.delete(params, "row_id")) do
      json(conn, %{row: row_json(row)})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def rename_category(conn, %{"category_id" => category_id} = params) do
    case AdCategories.rename_category(category_id, params) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def import_rows(conn, %{"rows" => rows} = params) when is_list(rows) do
    opts = [cohort: params["cohort"], dry_run: dry_run?(params)]

    case AdCategories.upsert_rows(rows, opts) do
      {:ok, report} -> json(conn, report)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def import_rows(conn, _params), do: Responder.error(conn, "rows must be a list of row objects")

  def set_cohort(conn, params) do
    case AdCategories.set_cohort(Map.take(params, ~w(row_ids category_id)), params["cohort"]) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def remap(conn, params) do
    spec = Map.take(params, ~w(mappings media_piece_ids to_row_id))

    case AdCategories.remap_media_pieces(spec, dry_run: dry_run?(params)) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def prune(conn, params) do
    selector = Map.take(params, ~w(row_ids category_id cohort))

    case AdCategories.prune_unused(selector, dry_run: dry_run?(params)) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"row_id" => row_id}) do
    with {:ok, row} <- fetch(row_id),
         {:ok, _} <- AdCategories.delete_row(row) do
      json(conn, %{deleted: row.row_id})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp fetch(row_id) do
    case AdCategories.get_by_row_id(row_id) do
      nil -> {:error, :not_found}
      row -> {:ok, row}
    end
  end

  defp dry_run?(params), do: params["dry_run"] in [true, "true", "1"]

  defp row_json(%AdCategory{} = row) do
    Map.take(row, [
      :id,
      :row_id,
      :category_id,
      :category_name,
      :category_label,
      :ad_label,
      :age_gated,
      :age_min,
      :sales_channel_default,
      :meta_1,
      :meta_2,
      :meta_3,
      :sort_order,
      :cohort,
      :active,
      :media_pieces_count,
      :active_media_pieces_count
    ])
  end
end
