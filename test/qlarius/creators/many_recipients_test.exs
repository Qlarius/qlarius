defmodule Qlarius.Creators.ManyRecipientsTest do
  use Qlarius.DataCase, async: false

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Sponster.Recipients
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets.LedgerHeader

  setup_all do
    Code.require_file("priv/repo/migrations/20261031220000_creators_have_many_recipients.exs")
    :ok
  end

  test "backfill keeps an existing one-recipient creator as the primary" do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "legacy-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, recipient} =
      Recipients.create_recipient(%{
        "user_id" => user.id,
        "name" => "Legacy Magazine",
        "site_url" => "https://legacy.example",
        "recipient_type_id" => 1,
        "split_code" => Ecto.UUID.generate(),
        "target_amount" => "0.00"
      })

    assert is_nil(recipient.creator_id)
    refute recipient.is_primary

    {:ok, creator} =
      %Creator{}
      |> Creator.changeset(%{"name" => "Legacy Media"})
      |> Ecto.Changeset.change(%{recipient_id: recipient.id})
      |> Repo.insert()

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        "name" => "Legacy Catalog",
        "url" => "https://legacy.example",
        "type" => "catalog",
        "group_type" => "section",
        "piece_type" => "article"
      })
      |> Repo.insert!()

    assert is_nil(catalog.recipient_id)

    migration = Module.concat(Qlarius.Repo.Migrations, CreatorsHaveManyRecipients)
    Enum.each(apply(migration, :backfill_sql, []), &Repo.query!/1)
    Repo.query!(apply(migration, :catalog_backfill_sql, []))

    recipient = Repo.get!(Recipient, recipient.id)
    assert recipient.creator_id == creator.id
    assert recipient.is_primary
    assert Repo.get!(Catalog, catalog.id).recipient_id == recipient.id
  end

  test "tiqit revenue posts to the catalog recipient" do
    {:ok, creator} =
      Creators.create_creator(%{
        "name" => "CW#{rem(System.unique_integer([:positive]), 100_000)}"
      })

    {:ok, %{user: owner}} =
      Accounts.register_new_user(%{
        alias: "owner-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, phoenix} =
      Recipients.create_recipient(%{
        "user_id" => owner.id,
        "name" => "PHOENIX Magazine",
        "site_url" => "https://phoenixmag.com",
        "recipient_type_id" => 1,
        "split_code" => Ecto.UUID.generate(),
        "target_amount" => "0.00",
        "creator_id" => creator.id,
        "is_primary" => true
      })

    {:ok, garden} =
      Recipients.create_recipient(%{
        "user_id" => owner.id,
        "name" => "Phoenix Home & Garden",
        "site_url" => "https://phgmag.com",
        "recipient_type_id" => 1,
        "split_code" => Ecto.UUID.generate(),
        "target_amount" => "0.00",
        "creator_id" => creator.id,
        "is_primary" => false
      })

    creator.id
    |> then(&Repo.get!(Creator, &1))
    |> Ecto.Changeset.change(%{recipient_id: phoenix.id})
    |> Repo.update!()

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        "name" => "Home & Garden",
        "url" => "https://phgmag.com/#{System.unique_integer([:positive])}",
        "type" => "catalog",
        "group_type" => "section",
        "piece_type" => "article",
        "recipient_id" => garden.id
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{"title" => "Garden"})
      |> Repo.insert!()

    piece =
      %ContentPiece{content_group_id: group.id}
      |> ContentPiece.changeset(%{"title" => "Patios", "date_published" => ~D[2025-01-01]})
      |> Repo.insert!()

    class =
      %TiqitClass{content_piece_id: piece.id}
      |> TiqitClass.changeset(%{"duration_hours" => 3, "price" => "0.10"})
      |> Repo.insert!()

    {:ok, %{user: buyer}} =
      Accounts.register_new_user(%{
        alias: "buyer-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    assert :ok = Arcade.purchase_tiqit(Scope.for_user(buyer), class)

    garden_header = Repo.get_by!(LedgerHeader, recipient_id: garden.id)
    assert garden_header.balance == Decimal.new("0.10")
    assert Repo.get_by(LedgerHeader, recipient_id: phoenix.id) == nil
    assert Repo.get_by(LedgerHeader, creator_id: creator.id) == nil

    tiqit = Repo.get_by!(Tiqit, content_piece_id: piece.id)
    assert {:ok, _} = Arcade.undo_tiqit!(Scope.for_user(buyer), tiqit)
    assert Repo.get!(LedgerHeader, garden_header.id).balance == Decimal.new("0.00")
  end
end
