defmodule QlariusWeb.CurrentMarketerControllerTest do
  use QlariusWeb.ConnCase, async: true

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Marketer
  alias Qlarius.Accounts.Marketers
  alias Qlarius.Repo

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "cm-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    member_of = marketer_fixture("Member Org")
    {:ok, _} = Marketers.create_marketer_membership(member_of.id, user.id, :member)

    %{
      conn: log_in_user(conn, user),
      user: user,
      member_of: member_of,
      outsider: marketer_fixture("Outsider")
    }
  end

  defp marketer_fixture(name) do
    %Marketer{}
    |> Marketer.changeset(%{business_name: "#{name} #{System.unique_integer([:positive])}"})
    |> Repo.insert!()
  end

  defp select(conn, marketer_id, return_to) do
    post(conn, ~p"/marketer/select/#{marketer_id}?#{[return_to: return_to]}")
  end

  describe "select" do
    test "stores a marketer the user belongs to and redirects back", %{
      conn: conn,
      member_of: member_of
    } do
      conn = select(conn, member_of.id, "/marketer/campaigns")

      assert redirected_to(conn) == "/marketer/campaigns"
      assert get_session(conn, :current_marketer_id) == member_of.id
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ member_of.business_name
    end

    test "refuses a marketer the user does not belong to", %{conn: conn, outsider: outsider} do
      conn = select(conn, outsider.id, "/admin/marketers")

      assert redirected_to(conn) == "/admin/marketers"
      assert get_session(conn, :current_marketer_id) == nil
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Marketer not found."
    end

    test "refuses a non-numeric id without crashing", %{conn: conn} do
      conn = select(conn, "abc", "/admin/marketers")

      assert redirected_to(conn) == "/admin/marketers"
      assert get_session(conn, :current_marketer_id) == nil
    end

    test "ignores a return_to outside the marketer pages", %{conn: conn, member_of: member_of} do
      for unsafe <- ["https://evil.example", "//evil.example", "/users/settings", nil] do
        conn = select(conn, member_of.id, unsafe)
        assert redirected_to(conn) == "/admin/marketers"
      end
    end
  end

  describe "marketer pages" do
    test "the first render already shows the selected marketer", %{
      conn: conn,
      member_of: member_of
    } do
      conn = select(conn, member_of.id, "/marketer/campaigns")

      for path <-
            ~w(/marketer/campaigns /marketer/media /marketer/sequences /marketer/targets /marketer/traits) do
        html = conn |> get(path) |> html_response(200)

        assert html =~ member_of.business_name, "expected #{path} to render the marketer"
        refute html =~ "No marketer selected"
      end
    end

    test "a stored id the user no longer belongs to renders as unselected", %{
      conn: conn,
      outsider: outsider
    } do
      html =
        conn
        |> Plug.Test.init_test_session(%{current_marketer_id: outsider.id})
        |> get(~p"/marketer/campaigns")
        |> html_response(200)

      assert html =~ "No marketer selected"
      refute html =~ outsider.business_name
    end

    test "the marketer list selects through a CSRF-protected POST link", %{
      conn: conn,
      user: user,
      member_of: member_of
    } do
      user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()

      html = conn |> get(~p"/admin/marketers") |> html_response(200)

      assert html =~ ~s(id="select-marketer-#{member_of.id}")
      assert html =~ ~s(data-method="post")
      assert html =~ ~s(data-to="/marketer/select/#{member_of.id}?return_to=/admin/marketers")
    end
  end
end
