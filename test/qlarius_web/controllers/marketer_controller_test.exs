defmodule QlariusWeb.MarketerControllerTest do
  use QlariusWeb.ConnCase

  import Qlarius.AccountsFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  setup :register_and_log_in_user

  describe "index" do
    test "lists all marketers", %{conn: conn} do
      conn = get(conn, ~p"/marketers")
      assert html_response(conn, 200) =~ "Listing Marketers"
    end
  end

  describe "new marketer" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/marketers/new")
      assert html_response(conn, 200) =~ "New Marketer"
    end
  end

  describe "create marketer" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/marketers", marketer: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/marketers/#{id}"

      conn = get(conn, ~p"/marketers/#{id}")
      assert html_response(conn, 200) =~ "Marketer #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/marketers", marketer: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Marketer"
    end
  end

  describe "edit marketer" do
    setup [:create_marketer]

    test "renders form for editing chosen marketer", %{conn: conn, marketer: marketer} do
      conn = get(conn, ~p"/marketers/#{marketer}/edit")
      assert html_response(conn, 200) =~ "Edit Marketer"
    end
  end

  describe "update marketer" do
    setup [:create_marketer]

    test "redirects when data is valid", %{conn: conn, marketer: marketer} do
      conn = put(conn, ~p"/marketers/#{marketer}", marketer: @update_attrs)
      assert redirected_to(conn) == ~p"/marketers/#{marketer}"

      conn = get(conn, ~p"/marketers/#{marketer}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, marketer: marketer} do
      conn = put(conn, ~p"/marketers/#{marketer}", marketer: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Marketer"
    end
  end

  describe "delete marketer" do
    setup [:create_marketer]

    test "deletes chosen marketer", %{conn: conn, marketer: marketer} do
      conn = delete(conn, ~p"/marketers/#{marketer}")
      assert redirected_to(conn) == ~p"/marketers"

      assert_error_sent 404, fn ->
        get(conn, ~p"/marketers/#{marketer}")
      end
    end
  end

  defp create_marketer(%{scope: scope}) do
    marketer = marketer_fixture(scope)

    %{marketer: marketer}
  end
end
