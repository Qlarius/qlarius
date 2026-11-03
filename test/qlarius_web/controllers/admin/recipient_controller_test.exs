defmodule QlariusWeb.Admin.RecipientControllerTest do
  use QlariusWeb.ConnCase, async: false

  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.PromoSequences
  alias Qlarius.Sponster.Recipients

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "recipient-admin-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "shows the recipient brand image, not the creator image, and assigns a sequence", %{
    conn: conn,
    user: user
  } do
    {:ok, creator} =
      %Creator{}
      |> Creator.changeset(%{name: "Tammy", image: "creator-face.png"})
      |> Repo.insert()

    {:ok, recipient} =
      Recipients.create_recipient(%{
        "user_id" => user.id,
        "creator_id" => creator.id,
        "name" => "Yummy Food Blog",
        "site_url" => "https://localhost:4001/creators/#{creator.id}",
        "recipient_type_id" => 1,
        "split_code" => Ecto.UUID.generate(),
        "target_amount" => "0.00"
      })

    recipient =
      recipient
      |> Ecto.Changeset.change(%{
        promo_sequence_id: nil,
        graphic_url: %{file_name: "thank-you.png", updated_at: nil}
      })
      |> Repo.update!()

    conn = get(conn, ~p"/admin/recipients/#{recipient}")
    html = html_response(conn, 200)

    assert html =~ "thank-you.png"
    refute html =~ "creator-face.png"
    assert html =~ "Promo sequence"
    assert html =~ "None (built-in banners)"
    assert html =~ "id=\"promo-sequence-assign\""

    {:ok, sequence} = PromoSequences.create_sequence(%{"name" => "House special"})

    conn =
      put(conn, ~p"/admin/recipients/#{recipient}", %{
        "recipient" => %{"promo_sequence_id" => sequence.id},
        "return_to" => "show"
      })

    assert redirected_to(conn) == ~p"/admin/recipients/#{recipient}"
    assert Repo.get!(Qlarius.Sponster.Recipient, recipient.id).promo_sequence_id == sequence.id

    conn = get(recycle(conn), ~p"/admin/recipients/#{recipient}")
    assert html_response(conn, 200) =~ "House special"
  end
end
