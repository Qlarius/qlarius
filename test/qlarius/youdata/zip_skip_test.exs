defmodule Qlarius.YouData.ZipSkipTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures
  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts.{Scope, User}
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.TraitManager
  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.Traits.Trait

  setup do
    category = insert_category!("Places")
    user = Repo.insert!(%User{alias: "zip-skip-#{System.unique_integer([:positive])}"})

    home =
      category
      |> insert_trait!("Home Zip Code")
      |> Ecto.Changeset.change(%{input_type: "single_select_zip", skip_exempt: true})
      |> Repo.update!()

    work =
      category
      |> insert_trait!("Work Zip Code")
      |> Ecto.Changeset.change(%{
        input_type: "single_select_zip",
        skip_exempt: false,
        ripen_days: 7,
        stale_days: 365,
        expired_days: 1_095
      })
      |> Repo.update!()

    %{
      scope: %Scope{true_user: user, user: user},
      home: home,
      work: work
    }
  end

  test "only a zip that is not skip exempt receives a skip child", ctx do
    assert {:ok, nil} = TraitManager.ensure_skipped_child(ctx.scope, ctx.home)

    assert {:ok, skip} = TraitManager.ensure_skipped_child(ctx.scope, ctx.work)
    assert skip.trait_name == "Prefer not to say"
    assert skip.is_skipped_tag
    assert skip.display_order == 1

    assert {:ok, nil} = TraitManager.ensure_skipped_child(ctx.scope, ctx.work)
    assert Traits.active_skipped_child(ctx.work.id).id == skip.id
    assert Traits.active_skipped_child_id_by_parent([ctx.home.id, ctx.work.id]) == %{
             ctx.work.id => skip.id
           }
  end

  test "an existing skip answer is kept and a real zip code stays out of that role", ctx do
    zip =
      insert_trait!(nil, "60614", parent_trait_id: ctx.work.id)
      |> Ecto.Changeset.change(%{meta_1: "Chicago, IL", meta_2: "STANDARD", display_order: 10})
      |> Repo.update!()

    skip =
      insert_trait!(nil, "Prefer not to say", parent_trait_id: ctx.work.id)
      |> Ecto.Changeset.change(%{is_skipped_tag: true, display_order: 43_601, meta_2: "STANDARD"})
      |> Repo.update!()

    assert {:ok, nil} = TraitManager.ensure_skipped_child(ctx.scope, ctx.work)
    assert Traits.get_zip_code_trait(ctx.work.id, "60614").id == zip.id
    assert Traits.search_zip_codes(ctx.work.id, "606") == [
             %{id: zip.id, zip_code: "60614", location: "Chicago, IL"}
           ]

    marketer = marketer_fixture()
    group = trait_group_fixture(%{marketer_id: marketer.id}, [skip])
    me_file = Repo.insert!(%MeFile{})
    insert_tag!(me_file, skip, skip.trait_name)

    assert Traits.me_file_counts_for_trait_groups([group.id]) == %{group.id => 1}
  end

  test "a skip-exempt zip refuses a skip flag on its child", ctx do
    zip = insert_trait!(nil, "60614", parent_trait_id: ctx.home.id)

    assert {:error, changeset} =
             TraitManager.update_child_trait(ctx.scope, zip, %{"is_skipped_tag" => true})

    refute changeset.valid?
    refute Repo.get!(Trait, zip.id).is_skipped_tag
  end
end
