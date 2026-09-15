defmodule Qlarius.Accounts.Authz do
  @moduledoc """
  Scope-level authorization predicates.

  Admin status is read from `scope.true_user`, never `scope.user`, matching
  `QlariusWeb.UserAuth.require_admin_user/2`. The two differ when a proxy is
  active (see `User.active_proxy_user_or_self/1`): `true_user` is the real
  signed-in identity and `user` is whoever they are viewing as.

  Reading `true_user` is what prevents privilege escalation through the proxy
  feature — a non-admin proxying as an admin would gain admin powers if this
  read `scope.user`. The corollary is intentional: an admin viewing as another
  user keeps their own admin access, since their real identity is unchanged.

  Membership predicates such as `Creators.user_has_creator_access?/2` stay
  factual — they answer only "is there a membership row?" — so they remain
  usable for questions like "should this org appear in their switcher?".
  The admin bypass lives here and in the `accessible_*!/2` functions that
  call it, so there is exactly one place to audit.
  """

  alias Qlarius.Accounts.Scope

  @doc """
  Returns true when the caller is an admin acting as themselves.
  """
  def admin?(%Scope{true_user: %{role: "admin"}}), do: true
  def admin?(_scope), do: false

  @doc """
  Returns the acting user id for attribution, which is `scope.user` — the
  proxied user when proxying, otherwise the same as `true_user`.

  Authorization gets the admin bypass; attribution does not. An admin acting
  on an org they do not belong to is still recorded as themselves rather than
  as one of that org's members.
  """
  def acting_user_id(%Scope{user: %{id: id}}), do: id
  def acting_user_id(_scope), do: nil
end
