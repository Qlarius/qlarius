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

  def existing_tags_per_parent_trait(me_file_id, trait_id) do
    Repo.all(
      from mt in MeFileTag, where: mt.me_file_id == ^me_file_id and mt.trait_id == ^trait_id
    )
  end

  def create_replace_mefile_tags(me_file_id, parent_trait_id, child_trait_ids, user_id)
      when is_list(child_trait_ids) do
    Repo.transaction(fn ->
      from(mt in MeFileTag,
        join: t in Trait,
        on: mt.trait_id == t.id,
        where: mt.me_file_id == ^me_file_id and t.parent_trait_id == ^parent_trait_id
      )
      |> Repo.delete_all()

      child_trait_ids =
        Enum.map(child_trait_ids, fn
          id when is_binary(id) -> String.to_integer(id)
          id -> id
        end)

      trait_names =
        Repo.all(
          from t in Trait,
            where: t.id in ^child_trait_ids,
            select: {t.id, t.trait_name}
        )
        |> Map.new()

      Enum.each(child_trait_ids, fn child_id ->
        %MeFileTag{}
        |> MeFileTag.changeset(%{
          me_file_id: me_file_id,
          trait_id: child_id,
          tag_value: Map.get(trait_names, child_id),
          added_by: user_id,
          modified_by: user_id
        })
        |> Repo.insert!()
      end)
    end)

    :ok
  end

  def create_replace_mefile_tags(
        me_file_id,
        parent_trait_id,
        child_trait_ids,
        user_id,
        id_to_name_map
      )
      when is_list(child_trait_ids) and is_map(id_to_name_map) do
    Repo.transaction(fn ->
      from(mt in MeFileTag,
        join: t in Trait,
        on: mt.trait_id == t.id,
        where: mt.me_file_id == ^me_file_id and t.parent_trait_id == ^parent_trait_id
      )
      |> Repo.delete_all()

      child_trait_ids =
        Enum.map(child_trait_ids, fn
          id when is_binary(id) -> String.to_integer(id)
          id -> id
        end)

      Enum.each(child_trait_ids, fn child_id ->
        %MeFileTag{}
        |> MeFileTag.changeset(%{
          me_file_id: me_file_id,
          trait_id: child_id,
          tag_value: Map.get(id_to_name_map, child_id),
          added_by: user_id,
          modified_by: user_id
        })
        |> Repo.insert!()
      end)
    end)

    :ok
  end

  def parent_trait_with_tags_for_mefile(me_file_id, parent_trait_id) do
    parent = Repo.get!(Trait, parent_trait_id)

    tags =
      Repo.all(
        from mt in MeFileTag,
          join: t in Trait,
          on: mt.trait_id == t.id,
          where: mt.me_file_id == ^me_file_id and t.parent_trait_id == ^parent_trait_id,
          order_by: [asc: t.display_order, asc: t.trait_name],
          select: {t.id, t.trait_name, t.display_order}
      )

    {parent.id, parent.trait_name, parent.display_order, tags}
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
