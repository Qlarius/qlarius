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

  alias Qlarius.Accounts.User
  alias Qlarius.Offers
  alias Qlarius.Traits
  alias Qlarius.Wallets

  defstruct user: nil, wallet_balance: Decimal.new("0.0"), ads_count: 0, home_zip: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{
      ads_count: Offers.count_user_offers(user.id),
      user: user,
      wallet_balance: Wallets.get_user_current_balance(user),
      home_zip: Traits.get_user_home_zip(user)
    }
  end

  def for_user(nil), do: nil
end
