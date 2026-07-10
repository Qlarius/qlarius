defmodule Qlarius.MeCP.ProxyResolutionTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts.{User, UserProxy}
  alias Qlarius.MeCP
  alias Qlarius.MeCP.{AccessLog, Grants, Oracle}
  alias Qlarius.YouData.MeFiles.MeFile

  # Owner (true user) answers "Renter"; their demo persona answers "Owner" for
  # the same trait. The grant belongs to the owner; the MeFile served follows
  # whichever persona is active.
  defp seed_owner_and_persona! do
    owner = Repo.insert!(%User{alias: "owner-#{System.unique_integer([:positive])}"})
    persona = Repo.insert!(%User{alias: "persona-#{System.unique_integer([:positive])}"})

    owner_mf = Repo.insert!(%MeFile{user_id: owner.id})
    persona_mf = Repo.insert!(%MeFile{user_id: persona.id})

    demo = insert_category!("Demographics")
    housing = insert_trait!(demo, "Housing")
    insert_tag!(owner_mf, housing, "Renter")
    insert_tag!(persona_mf, housing, "Owner")

    grant =
      insert_grant!(owner_mf, insert_client!(), %{tier: 3, scope: %{}, user_id: owner.id})

    %{
      owner: owner,
      persona: persona,
      owner_mf: owner_mf,
      persona_mf: persona_mf,
      housing: housing,
      grant: grant
    }
  end

  defp activate_proxy!(true_user, proxy_user) do
    Repo.insert!(%UserProxy{
      true_user_id: true_user.id,
      proxy_user_id: proxy_user.id,
      active: true
    })
  end

  describe "effective_me_file_id/1" do
    test "no active proxy serves the owner's own MeFile" do
      ctx = seed_owner_and_persona!()
      assert MeCP.effective_me_file_id(ctx.grant) == ctx.owner_mf.id
    end

    test "an active proxy redirects to the persona's MeFile; deactivating restores" do
      ctx = seed_owner_and_persona!()
      proxy = activate_proxy!(ctx.owner, ctx.persona)

      assert MeCP.effective_me_file_id(ctx.grant) == ctx.persona_mf.id

      Repo.update!(Ecto.Changeset.change(proxy, active: false))
      assert MeCP.effective_me_file_id(ctx.grant) == ctx.owner_mf.id
    end

    test "legacy grants without an owner use the snapshot MeFile" do
      ctx = seed_owner_and_persona!()
      legacy = %{ctx.grant | user_id: nil}
      activate_proxy!(ctx.owner, ctx.persona)

      assert MeCP.effective_me_file_id(legacy) == ctx.owner_mf.id
    end

    test "an active persona without a MeFile falls back to the snapshot" do
      ctx = seed_owner_and_persona!()
      bare = Repo.insert!(%User{alias: "bare-#{System.unique_integer([:positive])}"})
      activate_proxy!(ctx.owner, bare)

      assert MeCP.effective_me_file_id(ctx.grant) == ctx.owner_mf.id
    end
  end

  describe "read paths follow the active persona" do
    test "capsule, oracle, and search serve persona data and log the served MeFile" do
      ctx = seed_owner_and_persona!()

      assert {:ok, [%{value: "Renter"}]} = Oracle.ask(ctx.grant, {:trait_values, ctx.housing.id})

      activate_proxy!(ctx.owner, ctx.persona)

      assert {:ok, [%{value: "Owner"}]} = Oracle.ask(ctx.grant, {:trait_values, ctx.housing.id})

      assert {:ok, rendered} = MeCP.request_capsule(ctx.grant)
      assert rendered =~ "Owner"
      refute rendered =~ "Renter"

      assert {:ok, [match]} = Oracle.search_traits(ctx.grant, "housing")
      assert match.has_data == true

      shapes = ctx.grant.id |> AccessLog.list_events_for_grant() |> Enum.map(& &1.response_shape)
      served = shapes |> Enum.map(& &1["me_file_id"]) |> Enum.sort()
      assert served == Enum.sort([ctx.owner_mf.id | List.duplicate(ctx.persona_mf.id, 3)])
    end
  end

  describe "ownership plumbing" do
    test "create_connector records the owning user" do
      ctx = seed_owner_and_persona!()

      {:ok, %{grant: grant}} =
        MeCP.create_connector(ctx.owner_mf, %{name: "Demo connector", user_id: ctx.owner.id})

      assert grant.user_id == ctx.owner.id
    end

    test "list_grants_for_owner returns owned grants plus legacy snapshot grants" do
      ctx = seed_owner_and_persona!()

      legacy =
        insert_grant!(ctx.owner_mf, insert_client!(%{name: "Legacy"}), %{tier: 2, scope: %{}})

      Repo.update!(Ecto.Changeset.change(legacy, user_id: nil))

      ids = Grants.list_grants_for_owner(ctx.owner.id, ctx.owner_mf.id) |> Enum.map(& &1.id)
      assert Enum.sort(ids) == Enum.sort([ctx.grant.id, legacy.id])
    end
  end
end
