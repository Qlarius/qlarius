defmodule QlariusWeb.Widgets.AdsExtServeLogTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Sponster.WidgetServeLog

  @sync_id "7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d"
  @ua "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"

  setup %{conn: conn} do
    owner =
      Repo.insert!(%Qlarius.Accounts.User{
        alias: "ads-ext-owner-#{System.unique_integer([:positive])}"
      })

    recipient =
      Repo.insert!(%Recipient{
        user_id: owner.id,
        name: "Ads ext publisher",
        split_code: Ecto.UUID.generate(),
        referral_code: "adsext-#{System.unique_integer([:positive])}"
      })

    conn =
      conn
      |> init_test_session(%{})
      |> put_req_header("user-agent", @ua)

    %{conn: conn, recipient: recipient}
  end

  defp widget_path(recipient, query) do
    "/widgets/ads_ext/#{recipient.split_code}?" <> URI.encode_query(query)
  end

  test "a connected load writes one row with the host page and page id", %{
    conn: conn,
    recipient: recipient
  } do
    {:ok, _view, _html} =
      live(
        conn,
        widget_path(recipient, %{host_url: "https://news.example.com/story", sync_id: @sync_id})
      )

    assert [log] = Repo.all(WidgetServeLog)
    assert log.recipient_id == recipient.id
    assert log.recipient_split_code == recipient.split_code
    assert log.host == "news.example.com"
    assert log.host_page_url == "https://news.example.com/story"
    assert log.page_load_id == @sync_id
    assert log.authed == false
    assert log.connect_count == 1
    assert log.user_agent == @ua
    assert log.device == "Mobile"
  end

  test "a reconnect from the same page counts as one load", %{conn: conn, recipient: recipient} do
    url = widget_path(recipient, %{host_url: "https://news.example.com/", sync_id: @sync_id})

    {:ok, _view, _html} = live(conn, url)
    {:ok, _view, _html} = live(conn, url)

    assert [%{connect_count: 2}] = Repo.all(WidgetServeLog)
  end

  test "the static render alone writes nothing", %{conn: conn, recipient: recipient} do
    conn |> get(widget_path(recipient, %{sync_id: @sync_id})) |> html_response(200)

    assert Repo.all(WidgetServeLog) == []
  end

  test "an unknown split code writes nothing", %{conn: conn} do
    {:ok, _view, _html} =
      live(conn, "/widgets/ads_ext/#{Ecto.UUID.generate()}?sync_id=#{@sync_id}")

    assert Repo.all(WidgetServeLog) == []
  end
end
