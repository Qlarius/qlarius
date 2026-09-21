defmodule Qlarius.YouData.TraitGuards do
  @moduledoc """
  Catalog rules shared by the admin JSON API and design packs.

  Age (parent id 93) and zip parents refuse child replacement and input-type
  changes unless the caller passes `force`. Force does not remap MeFile tags.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait

  @age_parent_id 93
  @input_types ~w(single_select multi_select single_select_zip)

  def input_types, do: @input_types
  def age_parent_id, do: @age_parent_id

  def protected?(%Trait{id: @age_parent_id}), do: true
  def protected?(%Trait{parent_trait_id: @age_parent_id}), do: true
  def protected?(%Trait{input_type: "single_select_zip"}), do: true
  def protected?(_), do: false

  def valid_input_type?(type), do: type in @input_types

  def ensure_input_type_change(%Trait{} = parent, new_type, force) do
    cond do
      new_type in [nil, parent.input_type] ->
        :ok

      new_type not in @input_types ->
        {:error, :invalid_input_type}

      force ->
        :ok

      protected?(parent) ->
        {:error, :protected_parent}

      parent.input_type == "multi_select" and new_type == "single_select" and
          multiple_tags?(parent) ->
        {:error, :multiple_tags}

      true ->
        :ok
    end
  end

  def ensure_child_mutation(%Trait{} = parent, force) do
    if protected?(parent) and not force do
      {:error, :protected_parent}
    else
      :ok
    end
  end

  def multiple_tags?(%Trait{} = parent) do
    child_ids =
      Repo.all(from t in Trait, where: t.parent_trait_id == ^parent.id, select: t.id)

    if child_ids == [] do
      false
    else
      Repo.one(
        from m in MeFileTag,
          where: m.trait_id in ^child_ids,
          group_by: m.me_file_id,
          having: count(m.id) > 1,
          select: m.me_file_id,
          limit: 1
      ) != nil
    end
  end

  def tag_count(trait_ids) when trait_ids == [], do: 0

  def tag_count(trait_ids) do
    Repo.one(from m in MeFileTag, where: m.trait_id in ^trait_ids, select: count(m.id)) || 0
  end
end
