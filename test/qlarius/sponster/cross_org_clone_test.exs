defmodule Qlarius.Sponster.CrossOrgCloneTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Accounts.{Authz, Marketers, Scope, UserProxy}
  alias Qlarius.Creators
  alias Qlarius.Sponster.Campaigns.{Campaign, Target, Targets, TraitGroup}

  # Built locally rather than via `Qlarius.AccountsFixtures`, whose `user_fixture`
  # still calls the removed `Accounts.register_user/1`.
  defp user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        alias: "user-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, %{user: user}} = Accounts.register_new_user(attrs)
    user
  end

  defp admin_user, do: user_fixture(%{role: "admin"})

  defp proxy!(true_user, proxy_user) do
    Repo.insert!(
      UserProxy.changeset(%UserProxy{}, %{
        true_user_id: true_user.id,
        proxy_user_id: proxy_user.id,
        active: true
      })
    )
  end

  defp two_ring_audience(owner) do
    parent = parent_trait_fixture("Interests")
    music = trait_fixture(parent, "Music", 1)
    travel = trait_fixture(parent, "Travel", 2)
    g_music = trait_group_fixture(owner, [music])
    g_travel = trait_group_fixture(owner, [travel])

    target = target_fixture(owner, [[g_music], [g_music, g_travel]])

    %{
      target: target,
      traits: %{music: music, travel: travel},
      groups: %{music: g_music, travel: g_travel}
    }
  end

  defp trait_ids(group) do
    group.traits |> Enum.map(& &1.id) |> Enum.sort()
  end

  defp groups_by_title(target) do
    target.target_bands
    |> Enum.flat_map(& &1.trait_groups)
    |> Enum.uniq_by(& &1.id)
    |> Map.new(&{&1.title, &1})
  end

  describe "clone_across_orgs/4" do
    setup do
      user = user_fixture()
      marketer = marketer_fixture()
      creator = creator_fixture()

      {:ok, _} = Marketers.create_marketer_membership(marketer.id, user.id, :owner)
      {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)

      %{
        user: user,
        scope: Scope.for_user(user),
        marketer: marketer,
        creator: creator
      }
    end

    test "creator → marketer produces owner-rewritten groups and leaves the source untouched",
         ctx do
      source_owner = %{creator_id: ctx.creator.id}
      %{target: source, groups: groups, traits: traits} = two_ring_audience(source_owner)

      assert {:ok, clone} =
               Targets.clone_across_orgs(ctx.scope, source, {:marketer, ctx.marketer.id})

      refute clone.id == source.id
      assert clone.marketer_id == ctx.marketer.id
      assert clone.creator_id == nil
      assert clone.title == source.title
      assert clone.population_status == "not_populated"
      assert clone.user_created_by == ctx.user.id

      # Two bands, same bullseye flag, same group counts.
      source_bands = Targets.get_bands_for_target(source.id)
      clone_bands = Targets.get_bands_for_target(clone.id)
      assert length(clone_bands) == length(source_bands)

      assert Enum.map(clone_bands, &{&1.is_bullseye, length(&1.trait_groups)}) ==
               Enum.map(source_bands, &{&1.is_bullseye, length(&1.trait_groups)})

      # A group shared by both rings on the source is cloned once, not twice.
      clone_groups = groups_by_title(clone)
      assert map_size(clone_groups) == 2

      cloned_music = clone_groups[groups.music.title]
      cloned_travel = clone_groups[groups.travel.title]

      refute cloned_music.id == groups.music.id
      refute cloned_travel.id == groups.travel.id
      assert cloned_music.marketer_id == ctx.marketer.id
      assert cloned_music.creator_id == nil
      assert cloned_travel.marketer_id == ctx.marketer.id
      assert trait_ids(cloned_music) == [traits.music.id]
      assert trait_ids(cloned_travel) == [traits.travel.id]

      # Both clone bands that referenced the shared group still share *one* clone.
      music_refs =
        clone_bands
        |> Enum.flat_map(& &1.trait_groups)
        |> Enum.filter(&(&1.title == groups.music.title))
        |> Enum.map(& &1.id)
        |> Enum.uniq()

      assert music_refs == [cloned_music.id]

      # Source rows are byte-identical to before.
      reloaded_source = Repo.get!(Target, source.id)
      assert reloaded_source.creator_id == ctx.creator.id
      assert reloaded_source.marketer_id == nil

      assert Repo.get!(TraitGroup, groups.music.id).creator_id == ctx.creator.id
      assert Repo.get!(TraitGroup, groups.music.id).marketer_id == nil
    end

    test "marketer → creator is the same operation in the other direction", ctx do
      %{target: source} = two_ring_audience(%{marketer_id: ctx.marketer.id})

      assert {:ok, clone} =
               Targets.clone_across_orgs(ctx.scope, source, {:creator, ctx.creator.id},
                 title: "For content"
               )

      assert clone.creator_id == ctx.creator.id
      assert clone.marketer_id == nil
      assert clone.title == "For content"

      Enum.each(groups_by_title(clone), fn {_title, group} ->
        assert group.creator_id == ctx.creator.id
        assert group.marketer_id == nil
      end)
    end

    test "same-org is rejected and writes nothing", ctx do
      %{target: source} = two_ring_audience(%{creator_id: ctx.creator.id})

      assert {:error, :same_org} =
               Targets.clone_across_orgs(ctx.scope, source, {:creator, ctx.creator.id})

      assert Repo.aggregate(
               from(t in Target, where: t.creator_id == ^ctx.creator.id),
               :count
             ) == 1
    end

    test "a user with access to only the source is denied", ctx do
      stranger = user_fixture()
      {:ok, _} = Creators.create_creator_membership(ctx.creator.id, stranger.id, :member)

      %{target: source} = two_ring_audience(%{creator_id: ctx.creator.id})

      assert {:error, :unauthorized} =
               Targets.clone_across_orgs(
                 Scope.for_user(stranger),
                 source,
                 {:marketer, ctx.marketer.id}
               )
    end

    test "a user with access to only the destination is denied", ctx do
      stranger = user_fixture()
      {:ok, _} = Marketers.create_marketer_membership(ctx.marketer.id, stranger.id, :member)

      %{target: source} = two_ring_audience(%{creator_id: ctx.creator.id})

      assert {:error, :unauthorized} =
               Targets.clone_across_orgs(
                 Scope.for_user(stranger),
                 source,
                 {:marketer, ctx.marketer.id}
               )
    end

    test "an admin can clone without memberships on either side" do
      admin = admin_user()
      marketer = marketer_fixture()
      creator = creator_fixture()
      %{target: source} = two_ring_audience(%{creator_id: creator.id})

      assert {:ok, clone} =
               Targets.clone_across_orgs(
                 Scope.for_user(admin),
                 source,
                 {:marketer, marketer.id}
               )

      assert clone.marketer_id == marketer.id
      assert clone.user_created_by == admin.id
    end

    test "an admin viewing as another user keeps the bypass; attribution follows the acting user" do
      admin = admin_user()
      other = user_fixture()
      proxy!(admin, other)

      marketer = marketer_fixture()
      creator = creator_fixture()
      %{target: source} = two_ring_audience(%{creator_id: creator.id})

      scope = Scope.for_user(admin)
      assert Authz.admin?(scope)
      assert Authz.acting_user_id(scope) == other.id

      assert {:ok, clone} =
               Targets.clone_across_orgs(scope, source, {:marketer, marketer.id})

      assert clone.marketer_id == marketer.id
      assert clone.user_created_by == other.id
    end

    test "a non-admin proxying as an admin does not gain the bypass" do
      non_admin = user_fixture()
      admin = admin_user()
      proxy!(non_admin, admin)

      marketer = marketer_fixture()
      creator = creator_fixture()
      %{target: source} = two_ring_audience(%{creator_id: creator.id})

      scope = Scope.for_user(non_admin)
      refute Authz.admin?(scope)

      assert {:error, :unauthorized} =
               Targets.clone_across_orgs(scope, source, {:marketer, marketer.id})
    end

    test "a launched campaign against the clone does not freeze the source", ctx do
      %{target: source} = two_ring_audience(%{creator_id: ctx.creator.id})

      {:ok, clone} =
        Targets.clone_across_orgs(ctx.scope, source, {:marketer, ctx.marketer.id})

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      %Campaign{}
      |> Campaign.changeset(%{
        marketer_id: ctx.marketer.id,
        target_id: clone.id,
        media_sequence_id: 1,
        title: "Promote",
        start_date: now,
        launched_at: now
      })
      |> Repo.insert!()

      assert Targets.is_frozen?(clone.id)
      refute Targets.is_frozen?(source.id)
    end

    test "a foreign trait group on the source aborts the clone", ctx do
      %{target: source, groups: groups} = two_ring_audience(%{creator_id: ctx.creator.id})

      # Simulate a leaked row: the band still points at a group the source
      # org does not own. The clone must refuse rather than rewrite it.
      stranger = marketer_fixture()

      from(g in TraitGroup, where: g.id == ^groups.music.id)
      |> Repo.update_all(set: [creator_id: nil, marketer_id: stranger.id])

      assert {:error, :foreign_trait_group} =
               Targets.clone_across_orgs(ctx.scope, source, {:marketer, ctx.marketer.id})

      refute Repo.exists?(
               from t in Target,
                 where: t.marketer_id == ^ctx.marketer.id and t.title == ^source.title
             )
    end

    test "populate: true enqueues a job against the clone, not the source", ctx do
      %{target: source} = two_ring_audience(%{creator_id: ctx.creator.id})

      assert {:ok, clone} =
               Targets.clone_across_orgs(ctx.scope, source, {:marketer, ctx.marketer.id},
                 populate: true
               )

      assert Repo.get!(Target, clone.id).population_status == "populating"
      assert Repo.get!(Target, source.id).population_status == "not_populated"

      jobs =
        from(j in Oban.Job,
          where: j.worker == "Qlarius.Jobs.PopulateTargetWorker"
        )
        |> Repo.all()

      assert Enum.map(jobs, & &1.args["target_id"]) == [clone.id]
    end
  end
end
