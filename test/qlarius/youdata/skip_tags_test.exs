defmodule Qlarius.YouData.SkipTagsTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures
  import Qlarius.TargetingFixtures

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits

  setup do
    category = insert_category!("Diet")

    parent =
      category
      |> insert_trait!("Diet")
      |> Ecto.Changeset.change(input_type: "multi_select")
      |> Repo.update!()

    %{
      parent: parent,
      plants: child!(parent, "Plants"),
      fish: child!(parent, "Fish"),
      none: child!(parent, "None of these", %{is_exclusive: true}),
      skip: child!(parent, "Prefer not to say", %{is_skipped_tag: true})
    }
  end

  test "an exclusive answer is kept when other answers are saved too", ctx do
    me_file = Repo.insert!(%MeFile{})

    save(me_file, ctx.parent, [ctx.plants, ctx.none])
    assert tagged(me_file) == Enum.sort([ctx.plants.id, ctx.none.id])

    save(me_file, ctx.parent, [ctx.skip, ctx.fish])
    assert tagged(me_file) == Enum.sort([ctx.skip.id, ctx.fish.id])
  end

  test "a skip tag still counts in a trait group", ctx do
    marketer = marketer_fixture()
    group = trait_group_fixture(%{marketer_id: marketer.id}, [ctx.skip])
    me_file = Repo.insert!(%MeFile{})
    insert_tag!(me_file, ctx.skip, ctx.skip.trait_name)

    assert Traits.me_file_counts_for_trait_groups([group.id]) == %{group.id => 1}
  end

  defp child!(parent, name, attrs \\ %{}) do
    nil
    |> insert_trait!(name, parent_trait_id: parent.id)
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  defp save(me_file, parent, children) do
    assert :ok =
             MeFiles.create_replace_mefile_tags(
               me_file.id,
               parent.id,
               Enum.map(children, & &1.id),
               0
             )
  end

  defp tagged(me_file) do
    Repo.all(from mt in MeFileTag, where: mt.me_file_id == ^me_file.id, select: mt.trait_id)
    |> Enum.sort()
  end
end
