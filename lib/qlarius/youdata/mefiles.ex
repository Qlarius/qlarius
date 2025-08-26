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
        join: t in Trait,
        on: mt.trait_id == t.id,
        left_join: parent_t in Trait,
        on: t.parent_trait_id == parent_t.id,
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
      Map.put(acc, category.id, {category.id, category.name, category.display_order})
    end)
    |> Map.values()
    |> Enum.sort_by(fn {_id, name, display_order} -> [display_order, name] end)
  end

  defp add_parent_traits_to_categories(new_tag_map, raw_tag_map) do
    new_tag_map
    |> Enum.map(fn category ->
      # Get all parent traits for this category from raw_tag_map
      parent_traits =
        raw_tag_map
        |> Enum.filter(fn me_file_tag ->
          {id, _, _} = category
          me_file_tag.trait.trait_category.id == id
        end)
        |> Enum.map(fn me_file_tag ->
          trait = me_file_tag.trait
          # Use parent trait if exists, otherwise the trait itself
          trait = trait.parent_trait || nil
          {trait.id, trait.trait_name, trait.display_order}
        end)
        # Remove duplicates
        |> Enum.uniq_by(fn {id, _, _} -> id end)
        # Sort by display_order
        |> Enum.sort_by(fn {_, _, display_order} -> display_order end)

      {category, parent_traits}
    end)
    |> Map.new()
  end

  defp add_tags_to_parent_traits(new_tag_map, raw_tag_map) do
    new_tag_map
    |> Enum.map(fn {category, parent_traits} ->
      parent_traits_with_tags =
        Enum.map(parent_traits, fn {id, name, display_order} ->
          tags =
            raw_tag_map
            |> Enum.filter(fn me_file_tag ->
              trait = me_file_tag.trait
              parent = trait.parent_trait || nil
              parent && parent.id == id
            end)
            |> Enum.map(fn me_file_tag ->
              if me_file_tag.trait.parent_trait do
                {me_file_tag.trait.id, me_file_tag.trait.trait_name,
                 me_file_tag.trait.display_order}
              else
                {me_file_tag.trait.id, me_file_tag.tag_value, me_file_tag.trait.display_order}
              end
            end)
            |> Enum.sort_by(fn {_id, name, display_order} -> [display_order, name] end)

          {id, name, display_order, tags}
        end)
        |> Enum.sort_by(fn {_id, name, display_order, _tags} -> [display_order, name] end)

      {category, parent_traits_with_tags}
    end)
    |> Enum.sort_by(fn {{_id, _name, display_order}, _parent_traits} ->
      [display_order, _name]
    end)
  end
end
