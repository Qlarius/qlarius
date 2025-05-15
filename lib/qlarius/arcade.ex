defmodule Qlarius.Arcade do
  import Ecto.Query

  alias Qlarius.Accounts.Scope
  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Arcade.Tiqit
  alias Qlarius.Arcade.TiqitClass
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo

  def has_valid_tiqit?(%Scope{} = _scope, %ContentPiece{} = _content) do
    # TODO make this work with the new data model
    false
    # now = DateTime.utc_now()

    # query =
    #   from t in Tiqit,
    #     join: tt in TiqitClass,
    #     on: t.tiqit_type_id == tt.id,
    #     where: tt.content_piece_id == ^content.id,
    #     where: t.user_id == ^scope.user.id,
    #     where: is_nil(t.expires_at) or t.expires_at > ^now

    # Repo.exists?(query)
  end

  def list_content_groups do
    Repo.all(from g in ContentGroup, order_by: [asc: g.title])
  end

  def get_content_group!(id) do
    Repo.get!(ContentGroup, id) |> Repo.preload(content_pieces: :tiqit_classes)
  end

  def list_pieces_in_content_group(%ContentGroup{} = group) do
    Repo.all(
      from c in ContentPiece,
        where: c.group_id == ^group.id,
        order_by: [desc: c.inserted_at],
        limit: 5,
        preload: [tiqit_classes: ^from(t in TiqitClass, order_by: t.price)]
    )
  end

  # TODO use Creators.get_content_piece! instead? ... maybe
  def get_content_piece!(id) do
    ContentPiece |> Repo.get!(id) |> Repo.preload(:tiqit_classes)
  end

  def create_content(attrs \\ %{}) do
    %ContentPiece{}
    |> ContentPiece.changeset(attrs)
    |> Repo.insert()
  end

  def update_content(%ContentPiece{} = content, attrs) do
    content
    |> ContentPiece.changeset(attrs)
    |> Repo.update()
  end

  def change_content(%ContentPiece{} = content, attrs \\ %{}) do
    ContentPiece.changeset(content, attrs)
  end

  def purchase_tiqit(%Scope{user: user} = scope, %TiqitClass{} = tiqit_class) do
    purchased_at = DateTime.utc_now()

    expires_at =
      if tiqit_class.duration_hours do
        DateTime.add(purchased_at, tiqit_class.duration_hours, :hour)
      end

    Repo.transaction(fn ->
      ledger_header = Repo.get_by!(LedgerHeader, user_id: user.id)

      amount = tiqit_class.price
      new_balance = Decimal.sub(ledger_header.balance, amount)

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amount: amount,
        running_balance: new_balance,
        description: "Purchased Tiqit"
      }
      |> Repo.insert!()

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      {:ok, _tiqit} =
        %Tiqit{user: scope.user, tiqit_class: tiqit_class}
        |> Tiqit.changeset(%{purchased_at: purchased_at, expires_at: expires_at})
        |> Repo.insert()
    end)

    :ok
  end
end
