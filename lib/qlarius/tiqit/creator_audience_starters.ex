defmodule Qlarius.Tiqit.CreatorAudienceStarters do
  @moduledoc """
  Resolves the creator “tag your content” starter from system globals.

  `CREATOR_CONTENT_TAG_PARENT_TRAIT_IDS` and
  `CREATOR_AUDIENCE_TAG_PARENT_TRAIT_IDS` are comma-separated parent trait
  IDs. List order is display order. Missing IDs are dropped.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.System
  alias Qlarius.YouData.Traits.Trait

  @content_key "CREATOR_CONTENT_TAG_PARENT_TRAIT_IDS"
  @audience_key "CREATOR_AUDIENCE_TAG_PARENT_TRAIT_IDS"

  def content_parent_traits, do: load(@content_key)
  def audience_parent_traits, do: load(@audience_key)

  def configured? do
    content_parent_traits() != [] or audience_parent_traits() != []
  end

  def parent_ids_from_global(name) do
    System.get_global_variable(name, "")
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn token ->
      case Integer.parse(token) do
        {id, ""} -> [id]
        _ -> []
      end
    end)
  end

  defp load(name) do
    ids = parent_ids_from_global(name)

    if ids == [] do
      []
    else
      found =
        from(t in Trait,
          where: t.id in ^ids and is_nil(t.parent_trait_id) and t.is_active == true
        )
        |> Repo.all()
        |> Map.new(&{&1.id, &1})

      ids
      |> Enum.map(&Map.get(found, &1))
      |> Enum.reject(&is_nil/1)
    end
  end
end
