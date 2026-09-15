defmodule Qlarius.Accounts.Marketers do
  @moduledoc """
  Marketer orgs and the memberships that grant users access to them.

  The membership API mirrors `Qlarius.Creators` so authorization reads the same
  on both sides. `list_marketers/1` and `get_marketer!/2` are genuinely scoped:
  admins reach every marketer, everyone else reaches only orgs they hold a
  `marketer_users` row for. Callers that previously received every marketer
  regardless of the scope they passed are narrowed by this — that is the point.
  """

  alias Qlarius.Repo
  alias Qlarius.Accounts.{Authz, Marketer, MarketerUser, Scope}

  import Ecto.Query

  # --- Scoped reads ---

  @doc """
  Lists the marketers the scope may act for: all of them for an admin,
  otherwise those the acting user holds a membership in.
  """
  def list_marketers(%Scope{} = scope) do
    scope
    |> accessible_marketers_query()
    |> order_by([m], asc: m.business_name)
    |> Repo.all()
  end

  @doc """
  Fetches a marketer the scope may act for, raising `Ecto.NoResultsError`
  when it does not exist or the scope has no access to it.
  """
  def get_marketer!(%Scope{} = scope, id), do: accessible_marketer!(scope, id)

  @doc """
  Same as `get_marketer!/2`, named to make the authorization intent explicit
  at call sites. This and `admin?/1` are the only places the admin bypass lives.
  """
  def accessible_marketer!(%Scope{} = scope, id) do
    scope
    |> accessible_marketers_query()
    |> where([m], m.id == ^id)
    |> Repo.one!()
  end

  defp accessible_marketers_query(%Scope{} = scope) do
    cond do
      Authz.admin?(scope) ->
        from(m in Marketer)

      user_id = Authz.acting_user_id(scope) ->
        from(m in Marketer,
          join: mu in MarketerUser,
          on: mu.marketer_id == m.id,
          where: mu.user_id == ^user_id
        )

      true ->
        # No user on the scope: reachable set is empty. `limit: 0` keeps this a
        # composable query so `Repo.one!` still raises `Ecto.NoResultsError`.
        from(m in Marketer, limit: 0)
    end
  end

  # --- Memberships ---

  @doc """
  Returns the list of marketers for a given user, ignoring admin status.

  Deliberately factual rather than authorization-aware, so it can answer
  "which orgs belong to this user?" — e.g. for an org switcher.
  """
  def list_user_marketers(user_id) when is_integer(user_id) do
    from(m in Marketer,
      join: mu in MarketerUser,
      on: mu.marketer_id == m.id,
      where: mu.user_id == ^user_id,
      order_by: [asc: m.business_name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a marketer for a specific user, ensuring they hold a membership.
  """
  def get_user_marketer!(user_id, marketer_id) do
    from(m in Marketer,
      join: mu in MarketerUser,
      on: mu.marketer_id == m.id,
      where: mu.user_id == ^user_id and m.id == ^marketer_id
    )
    |> Repo.one!()
  end

  @doc """
  Whether a membership row exists. Factual only — admins are not special here.
  """
  def user_has_marketer_access?(user_id, marketer_id) do
    from(mu in MarketerUser,
      where: mu.user_id == ^user_id and mu.marketer_id == ^marketer_id
    )
    |> Repo.exists?()
  end

  @doc """
  Gets the role of a user in a marketer, or nil when there is no membership.
  """
  def get_user_role(user_id, marketer_id) do
    from(mu in MarketerUser,
      where: mu.user_id == ^user_id and mu.marketer_id == ^marketer_id,
      select: mu.role
    )
    |> Repo.one()
  end

  @doc """
  Creates a marketer membership.
  """
  def create_marketer_membership(marketer_id, user_id, role \\ :member, opts \\ []) do
    %MarketerUser{}
    |> MarketerUser.changeset(%{
      marketer_id: marketer_id,
      user_id: user_id,
      role: role,
      invited_by_id: Keyword.get(opts, :invited_by_id)
    })
    |> Repo.insert()
  end

  @doc """
  Lists all members of a marketer.
  """
  def list_marketer_members(marketer_id) do
    from(mu in MarketerUser,
      where: mu.marketer_id == ^marketer_id,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Removes a membership.
  """
  def delete_marketer_membership(%MarketerUser{} = membership), do: Repo.delete(membership)

  @doc """
  Creates a marketer and makes the given user its owner, in one transaction.
  """
  def create_marketer_with_user(attrs, user_id) do
    Repo.transaction(fn ->
      with {:ok, marketer} <- do_create_marketer(attrs),
           {:ok, _membership} <- create_marketer_membership(marketer.id, user_id, :owner) do
        marketer
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # --- Writes ---

  def change_marketer(_scope, marketer \\ %Marketer{}, attrs \\ %{}) do
    Marketer.changeset(marketer, attrs)
  end

  def create_marketer(_scope, attrs), do: do_create_marketer(attrs)

  def update_marketer(_scope, %Marketer{} = marketer, attrs) do
    marketer
    |> Marketer.changeset(attrs)
    |> Repo.update()
  end

  def delete_marketer(_scope, %Marketer{} = marketer), do: Repo.delete(marketer)

  defp do_create_marketer(attrs) do
    %Marketer{}
    |> Marketer.changeset(attrs)
    |> Repo.insert()
  end
end
