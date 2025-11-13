defmodule Qlarius.YouData.TraitCategories do
  import Ecto.Query, warn: false
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.TraitCategory

  def list_trait_categories(_scope) do
    from(tc in TraitCategory,
      left_join: t in assoc(tc, :traits),
      where: is_nil(t.parent_trait_id) or is_nil(t.id),
      group_by: tc.id,
      order_by: [asc: tc.display_order, asc: tc.name],
      select: %{tc | traits: fragment("count(?)", t.id)}
    )
    |> Repo.all()
    |> Enum.map(fn category ->
      Map.put(category, :trait_count, category.traits)
    end)
  end

  def get_trait_category!(_scope, id) do
    Repo.get!(TraitCategory, id)
  end

  def create_trait_category(_scope, attrs) do
    %TraitCategory{}
    |> TraitCategory.changeset(attrs)
    |> Repo.insert()
  end

  def update_trait_category(_scope, %TraitCategory{} = category, attrs) do
    category
    |> TraitCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_trait_category(_scope, %TraitCategory{} = category) do
    if can_delete?(category) do
      Repo.delete(category)
    else
      {:error, :has_traits}
    end
  end

  def change_trait_category(_scope, %TraitCategory{} = category, attrs \\ %{}) do
    TraitCategory.changeset(category, attrs)
  end

  def can_delete?(%TraitCategory{} = category) do
    trait_count =
      from(t in Qlarius.YouData.Traits.Trait,
        where: t.trait_category_id == ^category.id and is_nil(t.parent_trait_id),
        select: count(t.id)
      )
      |> Repo.one()

    trait_count == 0
  end
end
