defmodule Qlarius.Accounts.MarketerMembershipTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts
  alias Qlarius.Accounts.{Authz, Marketer, Marketers, Scope, UserProxy}
  alias Qlarius.Creators
  alias Qlarius.Repo

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

  defp marketer!(business_name) do
    Repo.insert!(Marketer.changeset(%Marketer{}, %{business_name: business_name}))
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

  describe "membership predicates" do
    test "a user can belong to multiple marketers, and sees only those" do
      user = user_fixture()
      other = user_fixture()
      a = marketer!("Acme")
      b = marketer!("Beta")
      unrelated = marketer!("Gamma")

      {:ok, _} = Marketers.create_marketer_membership(a.id, user.id, :owner)
      {:ok, _} = Marketers.create_marketer_membership(b.id, user.id, :member)
      {:ok, _} = Marketers.create_marketer_membership(a.id, other.id, :member)

      assert Marketers.list_user_marketers(user.id) |> Enum.map(& &1.id) |> Enum.sort() ==
               Enum.sort([a.id, b.id])

      assert Marketers.user_has_marketer_access?(user.id, a.id)
      refute Marketers.user_has_marketer_access?(user.id, unrelated.id)

      assert Marketers.get_user_role(user.id, a.id) == :owner
      assert Marketers.get_user_role(user.id, b.id) == :member
      assert Marketers.get_user_role(user.id, unrelated.id) == nil
    end

    test "membership is unique per (user, marketer)" do
      user = user_fixture()
      m = marketer!("Acme")

      {:ok, _} = Marketers.create_marketer_membership(m.id, user.id, :owner)
      assert {:error, changeset} = Marketers.create_marketer_membership(m.id, user.id, :member)
      assert "has already been taken" in errors_on(changeset).user_id
    end

    test "predicates stay factual and are not admin-aware" do
      admin = admin_user()
      m = marketer!("Acme")

      # The admin can reach the org, but holds no membership in it. Keeping the
      # predicate factual is what lets it answer "show this in their switcher?"
      refute Marketers.user_has_marketer_access?(admin.id, m.id)
      assert Marketers.list_user_marketers(admin.id) == []
      assert Marketers.accessible_marketer!(Scope.for_user(admin), m.id).id == m.id
    end
  end

  describe "scoped access" do
    test "a member reaches only their own marketers" do
      user = user_fixture()
      mine = marketer!("Mine")
      theirs = marketer!("Theirs")
      {:ok, _} = Marketers.create_marketer_membership(mine.id, user.id, :owner)

      scope = Scope.for_user(user)

      assert Marketers.list_marketers(scope) |> Enum.map(& &1.id) == [mine.id]
      assert Marketers.get_marketer!(scope, mine.id).id == mine.id

      assert_raise Ecto.NoResultsError, fn ->
        Marketers.get_marketer!(scope, theirs.id)
      end
    end

    test "a non-member is denied even when memberships exist elsewhere" do
      user = user_fixture()
      member = user_fixture()
      m = marketer!("Acme")
      {:ok, _} = Marketers.create_marketer_membership(m.id, member.id, :owner)

      assert Marketers.list_marketers(Scope.for_user(user)) == []

      assert_raise Ecto.NoResultsError, fn ->
        Marketers.get_marketer!(Scope.for_user(user), m.id)
      end
    end

    test "an admin reaches every marketer without any membership" do
      admin = admin_user()
      a = marketer!("Acme")
      b = marketer!("Beta")

      scope = Scope.for_user(admin)
      ids = Marketers.list_marketers(scope) |> Enum.map(& &1.id)

      assert a.id in ids
      assert b.id in ids
      assert Marketers.get_marketer!(scope, a.id).id == a.id
      assert Marketers.get_marketer!(scope, b.id).id == b.id
    end

    test "a scope with no user reaches nothing" do
      m = marketer!("Acme")
      scope = %Scope{}

      assert Marketers.list_marketers(scope) == []
      assert_raise Ecto.NoResultsError, fn -> Marketers.get_marketer!(scope, m.id) end
    end
  end

  describe "admin bypass and the proxy feature" do
    test "a non-admin proxying as an admin does NOT gain admin powers" do
      non_admin = user_fixture()
      admin = admin_user()
      m = marketer!("Acme")

      proxy!(non_admin, admin)
      scope = Scope.for_user(non_admin)

      # The escalation this guards: `user` is the admin, `true_user` is not.
      assert scope.true_user.id == non_admin.id
      assert scope.user.id == admin.id

      refute Authz.admin?(scope)
      assert Marketers.list_marketers(scope) == []
      assert_raise Ecto.NoResultsError, fn -> Marketers.get_marketer!(scope, m.id) end
    end

    test "an admin viewing as another user keeps their own admin access" do
      admin = admin_user()
      other = user_fixture()
      m = marketer!("Acme")

      proxy!(admin, other)
      scope = Scope.for_user(admin)

      assert scope.true_user.id == admin.id
      assert scope.user.id == other.id

      assert Authz.admin?(scope)
      assert Marketers.get_marketer!(scope, m.id).id == m.id
    end

    test "attribution records the acting user, not the bypass" do
      admin = admin_user()
      other = user_fixture()
      proxy!(admin, other)

      scope = Scope.for_user(admin)

      # Authorization gets the bypass; attribution follows `scope.user`.
      assert Authz.admin?(scope)
      assert Authz.acting_user_id(scope) == other.id
    end
  end

  describe "create_marketer_with_user/2" do
    test "creates the marketer and an owner membership together" do
      user = user_fixture()

      assert {:ok, marketer} =
               Marketers.create_marketer_with_user(%{business_name: "Acme"}, user.id)

      assert Marketers.get_user_role(user.id, marketer.id) == :owner
      assert Marketers.get_marketer!(Scope.for_user(user), marketer.id).id == marketer.id
    end

    test "rolls back the marketer when the membership cannot be created" do
      assert {:error, _changeset} =
               Marketers.create_marketer_with_user(%{business_name: "Ghost"}, -1)

      refute Repo.exists?(from m in Marketer, where: m.business_name == "Ghost")
    end
  end

  describe "creator-side parity" do
    test "accessible_creator!/2 grants admins access and denies non-members" do
      admin = admin_user()
      user = user_fixture()
      {:ok, creator} = Creators.create_creator(%{"name" => "Tammy"})

      assert Creators.accessible_creator!(Scope.for_user(admin), creator.id).id == creator.id

      assert_raise Ecto.NoResultsError, fn ->
        Creators.accessible_creator!(Scope.for_user(user), creator.id)
      end

      {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)
      assert Creators.accessible_creator!(Scope.for_user(user), creator.id).id == creator.id
    end
  end
end
