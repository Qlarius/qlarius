defmodule Qlarius.Tiqit.Arcade.Arcade do
  import Ecto.Query

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Accounts.Scope
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets.Wallets
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo

  def get_valid_tiqit(%Scope{} = scope, %ContentPiece{} = piece) do
    now = DateTime.utc_now()

    piece = Repo.preload(piece, :content_group)

    query =
      from t in Tiqit,
        join: tc in assoc(t, :tiqit_class),
        join: u in assoc(t, :user),
        where:
          tc.content_piece_id == ^piece.id or
            tc.content_group_id == ^piece.content_group_id or
            tc.catalog_id == ^piece.content_group.catalog_id,
        where: u.id == ^scope.user.id,
        where: is_nil(t.expires_at) or t.expires_at > ^now,
        limit: 1

    Repo.one(query)
  end

  def has_valid_tiqit?(%Scope{} = scope, %ContentPiece{} = piece) do
    !!get_valid_tiqit(scope, piece)
  end

  def list_content_groups do
    Repo.all(from g in ContentGroup, order_by: [asc: g.title])
  end

  def get_content_group!(id) do
    ContentGroup
    |> Repo.get!(id)
    |> Repo.preload([
      :tiqit_classes,
      catalog: :tiqit_classes,
      content_pieces: :tiqit_classes
    ])
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

  def get_tiqit_class_for_piece!(class_id, %ContentPiece{} = piece, %ContentGroup{} = group) do
    class = TiqitClass |> Repo.get!(class_id)

    # for security, validate the tiqit belongs to a piece/group/catalog
    # in the current arcade
    classes = piece.tiqit_classes ++ group.tiqit_classes ++ group.catalog.tiqit_classes

    id = String.to_integer(class_id)

    if Enum.find(classes, &(&1.id == id)) do
      class
    else
      raise "invalid tiqit class"
    end
  end

  # TODO use Creators.get_content_piece! instead? ... maybe
  def get_content_piece!(id) do
    ContentPiece |> Repo.get!(id) |> Repo.preload([:content_group, :tiqit_classes])
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

  # Added missing function that was being called from TiqitController
  def list_user_tiqits(user) do
    Repo.all(
      from t in Tiqit,
        join: u in assoc(t, :user),
        where: u.id == ^user.id,
        order_by: [desc: t.purchased_at],
        preload: [:tiqit_class]
    )
  end

  def purchase_tiqit(%Scope{user: user} = _scope, %TiqitClass{} = tiqit_class) do
    purchased_at = DateTime.utc_now()

    expires_at =
      if tiqit_class.duration_hours do
        DateTime.add(purchased_at, tiqit_class.duration_hours, :hour)
      end

    Repo.transaction(fn ->
      ledger_header = %LedgerHeader{} = Wallets.get_me_file_ledger_header(user.me_file)
      me_file = %MeFile{} = user.me_file

      amount = Decimal.negate(tiqit_class.price)
      new_balance = Decimal.add(ledger_header.balance, amount)

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amt: amount,
        running_balance: new_balance,
        description: "Tiqit purchase"
      }
      |> Repo.insert!()

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      {:ok, _tiqit} =
        %Tiqit{me_file: me_file, tiqit_class: tiqit_class}
        |> Tiqit.changeset(%{purchased_at: purchased_at, expires_at: expires_at})
        |> Repo.insert()
    end)

    :ok
  end
end
