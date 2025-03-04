defmodule Qlarius.Ledger do
  @moduledoc """
  The Ledger context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo
  alias Qlarius.LedgerHeader
  alias Qlarius.LedgerEntry

  @doc """
  Gets a user's ledger header.
  """
  def get_user_ledger_header(user_id) do
    Repo.get_by(LedgerHeader, user_id: user_id)
    |> Repo.preload(:user)
  end

  @doc """
  Gets a paginated list of ledger entries for a ledger header.
  """
  def list_ledger_entries(ledger_header_id, page, per_page \\ 20) do
    offset = (page - 1) * per_page

    query =
      from e in LedgerEntry,
        where: e.ledger_header_id == ^ledger_header_id,
        order_by: [desc: e.inserted_at],
        limit: ^per_page,
        offset: ^offset

    entries = Repo.all(query)

    total_entries =
      from(e in LedgerEntry, where: e.ledger_header_id == ^ledger_header_id)
      |> Repo.aggregate(:count)

    total_pages = ceil(total_entries / per_page)

    %{
      entries: entries,
      page_number: page,
      page_size: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end
end
