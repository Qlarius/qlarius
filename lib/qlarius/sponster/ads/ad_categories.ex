defmodule Qlarius.Sponster.Ads.AdCategories do
  import Ecto.Query, warn: false
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.AdCategory

  def list_ad_categories(_scope) do
    from(ac in AdCategory,
      left_join: mp in assoc(ac, :media_pieces),
      left_join: mr in assoc(mp, :media_runs),
      left_join: ms in assoc(mr, :media_sequence),
      left_join: c in assoc(ms, :campaigns),
      on: is_nil(c.deactivated_at),
      group_by: ac.id,
      order_by: [asc: ac.ad_category_name],
      select: %{
        ac
        | media_pieces:
            fragment(
              "count(DISTINCT CASE WHEN ? IS NULL THEN ? END)",
              c.deactivated_at,
              mp.id
            )
      }
    )
    |> Repo.all()
    |> Enum.map(fn category ->
      Map.put(category, :active_media_pieces_count, category.media_pieces)
    end)
  end

  def search_ad_categories(_scope, query) when is_binary(query) and query != "" do
    search_term = "%#{String.downcase(query)}%"

    from(ac in AdCategory,
      left_join: mp in assoc(ac, :media_pieces),
      left_join: mr in assoc(mp, :media_runs),
      left_join: ms in assoc(mr, :media_sequence),
      left_join: c in assoc(ms, :campaigns),
      on: is_nil(c.deactivated_at),
      where: fragment("LOWER(?)", ac.ad_category_name) |> like(^search_term),
      group_by: ac.id,
      order_by: [asc: ac.ad_category_name],
      select: %{
        ac
        | media_pieces:
            fragment(
              "count(DISTINCT CASE WHEN ? IS NULL THEN ? END)",
              c.deactivated_at,
              mp.id
            )
      }
    )
    |> Repo.all()
    |> Enum.map(fn category ->
      Map.put(category, :active_media_pieces_count, category.media_pieces)
    end)
  end

  def search_ad_categories(scope, _query), do: list_ad_categories(scope)

  def get_ad_category!(_scope, id) do
    Repo.get!(AdCategory, id)
  end

  def create_ad_category(_scope, attrs) do
    %AdCategory{}
    |> AdCategory.changeset(attrs)
    |> Repo.insert()
  end

  def create_ad_categories_batch(_scope, names_text) when is_binary(names_text) do
    names =
      names_text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    existing_names =
      from(ac in AdCategory, select: ac.ad_category_name)
      |> Repo.all()
      |> MapSet.new(&String.downcase/1)

    results =
      Enum.reduce(names, %{created: 0, skipped: 0}, fn name, acc ->
        if MapSet.member?(existing_names, String.downcase(name)) do
          %{acc | skipped: acc.skipped + 1}
        else
          case create_ad_category(nil, %{ad_category_name: name}) do
            {:ok, _} -> %{acc | created: acc.created + 1}
            {:error, _} -> %{acc | skipped: acc.skipped + 1}
          end
        end
      end)

    {:ok, results}
  end

  def update_ad_category(_scope, %AdCategory{} = category, attrs) do
    category
    |> AdCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_ad_category(_scope, %AdCategory{} = category) do
    if can_delete?(category) do
      Repo.delete(category)
    else
      {:error, :has_active_media_pieces}
    end
  end

  def change_ad_category(_scope, %AdCategory{} = category, attrs \\ %{}) do
    AdCategory.changeset(category, attrs)
  end

  def can_delete?(%AdCategory{} = category) do
    active_media_pieces_count =
      from(mp in Qlarius.Sponster.Ads.MediaPiece,
        join: mr in assoc(mp, :media_runs),
        join: ms in assoc(mr, :media_sequence),
        join: c in assoc(ms, :campaigns),
        where: mp.ad_category_id == ^category.id and is_nil(c.deactivated_at),
        select: count(mp.id)
      )
      |> Repo.one()

    active_media_pieces_count == 0
  end
end
