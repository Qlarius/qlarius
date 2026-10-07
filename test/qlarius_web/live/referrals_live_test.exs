defmodule QlariusWeb.ReferralsLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  setup %{conn: conn} do
    trait = fn attrs ->
      Repo.insert!(
        struct(
          Trait,
          Map.merge(%{input_type: "text", display_order: 1, modified_by: 0, added_by: 0}, attrs)
        )
      )
    end

    trait.(%{id: 1, trait_name: "Sex"})
    trait.(%{id: 93, trait_name: "Age"})
    trait.(%{id: 200_001, parent_trait_id: 1, trait_name: "Male"})
    trait.(%{id: 200_093, parent_trait_id: 93, trait_name: "25-34"})

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "refs-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    %{conn: log_in_user(conn, user)}
  end

  test "a new member sees the summary, their link and code, and the referrer form", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/referrals")

    assert html =~ "wallet-summary__hero"
    assert html =~ "paid from 0 referrals"
    assert html =~ "Your link"
    assert html =~ ~s(id="referral-link-input")
    assert html =~ ~s(id="referral-code-text")
    assert html =~ "Did someone refer you?"
    assert html =~ ~s(phx-submit="save_referral_code")

    # Nothing pending, nobody referred yet, so one column
    refute html =~ "referral-pending"
    refute html =~ "People you referred"
    refute html =~ "referrals-board--split"
    refute html =~ "Earnings"
  end

  test "an unknown referral code shows an error under the field", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/referrals")

    html = view |> form("form[phx-submit='save_referral_code']", code: "nope") |> render_submit()

    assert html =~ "Invalid referral code"
  end
end
