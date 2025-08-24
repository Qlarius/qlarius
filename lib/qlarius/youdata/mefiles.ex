defmodule Qlarius.YouData.MeFiles do
  import Ecto.Query
  alias Qlarius.YouData.MeFiles.{MeFile, MeFileTag}
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.Repo

  def me_file_for_user(user_id) do
    Repo.one(from mf in MeFile, where: mf.user_id == ^user_id)
  end

  def me_file_tags_with_parent_traits_and_categories(me_file_id) do
    Repo.all(
      from mt in MeFileTag,
      join: t in Trait, on: mt.trait_id == t.id,
      left_join: parent_t in Trait, on: t.parent_trait_id == parent_t.id,
      where: mt.me_file_id == ^me_file_id,
      preload: [trait: [:trait_category, :parent_trait]]
    )
  end

  def me_file_tag_map_by_category_trait_tag(me_file_id) do
    raw_tag_map = me_file_tags_with_parent_traits_and_categories(me_file_id)

    raw_tag_map
    |> unique_categories_in_display_order()
    |> add_parent_traits_to_categories(raw_tag_map)
    |> add_tags_to_parent_traits(raw_tag_map)
  end

  defp unique_categories_in_display_order(me_file_tags) do
    me_file_tags
    |> Enum.reduce(%{}, fn me_file_tag, acc ->
      category = me_file_tag.trait.trait_category
      Map.put(acc, category.id, category)
    end)
    |> Map.values()
    |> Enum.sort_by(&[&1.display_order, &1.name])
  end


  defp add_parent_traits_to_categories(new_tag_map, raw_tag_map) do
    new_tag_map
    |> Enum.map(fn category ->
      # Get all parent traits for this category from raw_tag_map
      parent_traits =
        raw_tag_map
        |> Enum.filter(fn me_file_tag ->
          me_file_tag.trait.trait_category.id == category.id
        end)
        |> Enum.map(fn me_file_tag ->
          trait = me_file_tag.trait
          trait.parent_trait || trait  # Use parent trait if exists, otherwise the trait itself
        end)
        |> Enum.uniq_by(& &1.id)  # Remove duplicates
        |> Enum.sort_by(&[&1.display_order, &1.trait_name])  # Sort by display_order then name

      {category, parent_traits}
    end)
    |> Map.new()
  end

  defp add_tags_to_parent_traits(new_tag_map, raw_tag_map) do
    new_tag_map
    |> Enum.map(fn {category, parent_traits} ->
      parent_traits_with_tags = Enum.map(parent_traits, fn parent_trait ->
        tags = raw_tag_map
          |> Enum.filter(fn me_file_tag ->
            trait = me_file_tag.trait
            parent = trait.parent_trait || trait
            parent.id == parent_trait.id
          end)
          |> Enum.map(fn me_file_tag ->
            if me_file_tag.trait.parent_trait do
              me_file_tag.trait.trait_name
            else
              me_file_tag.tag_value
            end
          end)
          |> Enum.sort()

        {parent_trait.id, parent_trait.trait_name, tags}
      end)
      |> Enum.sort_by(fn {_id, name, _tags} -> name end)

      {category, parent_traits_with_tags}
    end)
    |> Enum.sort_by(fn {category, _parent_traits} -> [category.display_order, category.name] end)
  end


end
