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

  alias Qlarius.Legacy.{User, MeFile, LedgerHeader}
  alias Qlarius.{LegacyRepo, Wallets}
  alias Decimal

  defstruct user: nil,
            wallet_balance: nil,
            ads_count: nil,
            home_zip: nil,
            tag_count: nil,
            trait_count: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(user) do
    user = User.active_proxy_user_or_self(user)
    me_file = LegacyRepo.get_by(MeFile, user_id: user.id)
    ledger_header = LegacyRepo.get_by(LedgerHeader, me_file_id: me_file.id)

    %__MODULE__{
      user: user,
      home_zip: MeFile.home_zip(me_file),
      ads_count: MeFile.ad_offer_count(me_file),
      trait_count: MeFile.trait_tag_count(me_file),
      tag_count: MeFile.tag_count(me_file),
      wallet_balance: ledger_header.balance
    }
  end

  def for_user(nil), do: nil
end
