defmodule QlariusWeb.ConnectAuthSheetTest do
  # Mutates application env (phone verification bypass), so not async.
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  @sheet "#connect-auth-sheet"

  setup do
    for {key, value} <- [bypass_phone_verification: true, skip_carrier_validation: true] do
      previous = Application.get_env(:qlarius, key)
      Application.put_env(:qlarius, key, value)

      on_exit(fn ->
        if is_nil(previous),
          do: Application.delete_env(:qlarius, key),
          else: Application.put_env(:qlarius, key, previous)
      end)
    end

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
    trait.(%{id: 200_002, parent_trait_id: 1, trait_name: "Female"})
    trait.(%{id: 200_001, parent_trait_id: 1, trait_name: "Male", display_order: 2})
    trait.(%{id: 200_093, parent_trait_id: 93, trait_name: "25-34"})

    :ok
  end

  # Each test uses its own number: send_code allows 3 sends per number per 10 minutes.
  defp enter_phone(view, digits) do
    view |> with_target(@sheet) |> render_hook("update_mobile", %{"value" => digits})
    view |> element("#{@sheet} form") |> render_submit()
  end

  defp verify(view),
    do: view |> with_target(@sheet) |> render_hook("verify_code", %{"code" => "000000"})

  test "a new number goes phone, code, welcome, alias, then data", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/connect")
    assert html =~ "Connect via mobile"

    html = enter_phone(view, "5550104242")
    assert html =~ "Enter your code"
    assert html =~ "555-010-4242"

    html = verify(view)
    assert html =~ "is new here"

    html =
      view |> element("#{@sheet} button[phx-click='signup_intro_continue']") |> render_click()

    assert html =~ "Build your alias"
    assert html =~ "Step 1 of 3"

    view
    |> with_target(@sheet)
    |> render_click("select_base_name", %{"base_name" => "calm-river"})

    html = view |> with_target(@sheet) |> render_click("select_number", %{"number" => "4242"})
    assert html =~ "calm-river-4242"

    html = view |> element("#{@sheet} button[phx-click='signup_next']") |> render_click()
    assert html =~ "Basic data"
    assert html =~ "Step 2 of 3"
    assert html =~ "Female"

    html = view |> element("#{@sheet} button[phx-click='signup_back']") |> render_click()
    assert html =~ "Build your alias"
    assert html =~ "calm-river-4242"
  end

  test "a known number signs in", %{conn: conn} do
    {:ok, _} =
      Accounts.register_new_user(%{
        alias: "known-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        mobile_number: "+15550107777",
        sex_trait_id: 200_002,
        age_trait_id: 200_093
      })

    {:ok, view, _html} = live(conn, ~p"/connect")
    enter_phone(view, "5550107777")
    html = verify(view)

    assert html =~ "Signing you in"
    assert_push_event(view, "qadabra:finalize-auth", %{token: token})
    assert is_binary(token)
  end

  test "Different number returns to the phone step and keeps the number", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/connect")
    enter_phone(view, "5550104243")

    html = view |> element("#{@sheet} button[phx-click='back_to_phone']") |> render_click()
    assert html =~ "Connect via mobile"
    assert html =~ ~s(value="555-010-4243")
  end

  test "Resend code stays on the code step and restarts its countdown", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/connect")
    html = enter_phone(view, "5550104244")
    assert html =~ ~s(id="connect-auth-sheet-resend-1")
    assert html =~ ~s(phx-hook="ResendCountdown")

    html = view |> element("#connect-auth-sheet-resend-1") |> render_click()
    assert html =~ "Enter your code"
    assert html =~ ~s(id="connect-auth-sheet-resend-2")
  end

  test "a short number is refused with a message", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/connect")
    html = enter_phone(view, "55501")

    assert html =~ "Enter a valid 10-digit number."
    assert html =~ "Connect via mobile"
  end
end
