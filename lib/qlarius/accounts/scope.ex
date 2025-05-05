defmodule Qlarius.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Qlarius.Accounts.UserScope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Qlarius.Accounts.Proxying
  alias Qlarius.Accounts.User
  alias Qlarius.Offers
  alias Qlarius.Traits
  alias Qlarius.Wallets

  defstruct user: nil,
            wallet_balance: Decimal.new("0.0"),
            ads_count: 0,
            home_zip: nil,
            true_user: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    proxy = Proxying.get_active_proxy_user(user)

    # 'true_user' is non-nil iff 'user' is a proxy
    {user, true_user} =
      if proxy do
        {proxy.proxy_user, user}
      else
        {user, nil}
      end

    %__MODULE__{
      ads_count: Offers.count_user_offers(user.id),
      home_zip: Traits.get_user_home_zip(user),
      true_user: true_user,
      user: user,
      wallet_balance: Wallets.get_user_current_balance(user)
    }
  end

  def for_user(nil), do: nil
end
