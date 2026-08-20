defmodule Qlarius.Wallets.Summary do
  @moduledoc """
  Server-authoritative consumer wallet figures.

  `activity_balance` is the ledger header total. Credit allowance is stored on
  the MeFile and is not a ledger entry.
  """

  @enforce_keys [
    :activity_balance,
    :balance_payable,
    :non_payable_balance,
    :credit_allowance,
    :available_to_spend,
    :available_to_tip,
    :credit_backed_tip_available?,
    :cash_out_eligible
  ]

  defstruct @enforce_keys
end
