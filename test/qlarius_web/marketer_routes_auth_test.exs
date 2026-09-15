defmodule QlariusWeb.MarketerRoutesAuthTest do
  @moduledoc """
  The `/marketer` routes manage campaigns, targets, trait groups, bids and
  media for a marketer org. Before the membership work they ran through a
  pipeline that only set a layout, and a `live_session` that merely *mounted*
  the scope, so they were reachable with no authentication at all.
  """

  use QlariusWeb.ConnCase, async: true

  alias Qlarius.Accounts

  @marketer_paths [
    "/marketer/campaigns",
    "/marketer/traits",
    "/marketer/targets",
    "/marketer/sequences",
    "/marketer/media"
  ]

  defp user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        alias: "user-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, %{user: user}} = Accounts.register_new_user(attrs)
    user
  end

  describe "unauthenticated access" do
    test "every marketer management route redirects to login", %{conn: conn} do
      for path <- @marketer_paths do
        conn = get(build_conn(), path)

        assert redirected_to(conn) == ~p"/connect",
               "expected #{path} to require authentication"
      end

      # The current-marketer setter is a write and must be protected too.
      conn = post(conn, ~p"/marketer/set_current_marketer", %{"marketer_id" => "1"})
      assert redirected_to(conn) == ~p"/connect"
    end
  end

  describe "authenticated access" do
    test "a signed-in user reaches the page", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/marketer/targets")

      assert html_response(conn, 200)
    end
  end
end
