defmodule QlariusWeb.TiqitArqadeGiftTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.ContentSharing
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, TiqitClass}

  setup do
    {:ok, creator} =
      Creators.create_creator(%{"name" => "Gift Creator #{System.unique_integer([:positive])}"})

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        name: "Gift Catalog",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        type: :catalog,
        group_type: :show,
        piece_type: :episode
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{title: "Gift Show"})
      |> Repo.insert!()

    %ContentPiece{content_group_id: group.id}
    |> ContentPiece.changeset(%{title: "Pilot", date_published: ~D[2025-01-01]})
    |> Repo.insert!()

    tiqit_class =
      %TiqitClass{content_group_id: group.id}
      |> TiqitClass.changeset(%{price: Decimal.new("1.00"), duration_hours: 24})
      |> Repo.insert!()

    {:ok, %{raw_token: token, raw_pin: pin, will_call: will_call}} =
      ContentSharing.create_gift(Scope.for_user(register_user!()), %{
        tiqit_class_id: tiqit_class.id,
        content_group_id: group.id
      })

    %{token: token, pin: pin, will_call: will_call}
  end

  test "a signed-out visitor sees the tiqit, Connect, and the claim deadline", %{
    conn: conn,
    token: token
  } do
    {:ok, view, _html} = live(conn, ~p"/tiqit/gift/#{token}")

    card = view |> element(~s(#gift-invitation-modal .tiqit-grid[data-status="gifted"][data-pending="true"])) |> render()
    assert card =~ "Gift Show"
    assert card =~ "Gift Creator"
    assert card =~ "awaiting pickup"

    assert has_element?(view, "#gift-invitation-connect", "Connect")
    assert render(view) =~ "to claim this pre-paid tiqit."
    assert card =~ ~r/Must claim before <span[^>]*>\d{2}\/\d{2}\/\d{4} \d{1,2}:\d{2} (am|pm)/
    assert has_element?(view, "button", "Let me browse first.")
    refute has_element?(view, "#gift-invitation-wallet-strip")
    refute has_element?(view, "#gift-claim-pin")
  end

  test "a signed-in visitor gets four PIN boxes that claim on the fourth digit", %{
    conn: conn,
    token: token,
    pin: pin
  } do
    conn = log_in_user(conn, register_user!())
    {:ok, view, _html} = live(conn, ~p"/tiqit/gift/#{token}")

    assert has_element?(view, ~s(#gift-claim-pin[data-length="4"][data-autofocus="true"]))
    assert view |> element("#gift-claim-pin") |> render() |> then(&Regex.scan(~r/otp-slot/, &1)) |> length() == 4
    assert render(view) =~ "Enter the 4-digit Claim PIN from your invitation."
    refute has_element?(view, "#gift-invitation-connect")

    render_hook(view, "verify-claim-pin", %{"code" => wrong_pin(pin)})
    assert render(view) =~ "That PIN didn&#39;t match. Try again."

    render_hook(view, "verify-claim-pin", %{"code" => pin})
    assert render(view) =~ "Tiqit claimed. Enjoy!"
  end

  defp wrong_pin(pin), do: Enum.find(["0000", "1111", "2222"], &(&1 != pin))

  defp register_user! do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "gift-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user
  end
end
