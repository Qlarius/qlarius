defmodule Qlarius.Sponster.WidgetServeLogsTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Sponster.WidgetServeLog
  alias Qlarius.Sponster.WidgetServeLogs
  alias Qlarius.Sponster.WidgetServeLogs.UserAgent

  @chrome "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"
  @iphone "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"

  setup do
    owner =
      Repo.insert!(%Qlarius.Accounts.User{
        alias: "serve-owner-#{System.unique_integer([:positive])}"
      })

    recipient =
      Repo.insert!(%Recipient{
        user_id: owner.id,
        name: "Serve log publisher",
        split_code: Ecto.UUID.generate(),
        referral_code: "serve-#{System.unique_integer([:positive])}"
      })

    %{recipient: recipient}
  end

  defp attrs(recipient, overrides \\ %{}) do
    Map.merge(
      %{
        recipient_id: recipient.id,
        recipient_split_code: recipient.split_code,
        recipient_referral_code: recipient.referral_code,
        authed: false,
        ip_address: "203.0.113.7",
        user_agent: @chrome,
        host_page_url: "https://news.example.com/story?id=1",
        page_load_id: "2C3D4E5F-6A7B-4C8D-9E0F-1A2B3C4D5E6F"
      },
      overrides
    )
  end

  test "a load inserts one row with the host and classified agent", %{recipient: recipient} do
    assert :ok = WidgetServeLogs.record(attrs(recipient))

    [log] = Repo.all(WidgetServeLog)
    assert log.recipient_id == recipient.id
    assert log.host == "news.example.com"
    assert log.host_page_url == "https://news.example.com/story?id=1"
    assert log.page_load_id == "2c3d4e5f-6a7b-4c8d-9e0f-1a2b3c4d5e6f"
    assert log.connect_count == 1
    assert log.browser == "Chrome"
    assert log.device == "Desktop"
    assert log.platform == "macOS"
    assert log.offers_count == nil
  end

  test "a reconnect from the same page increments connect_count", %{recipient: recipient} do
    :ok = WidgetServeLogs.record(attrs(recipient))
    :ok = WidgetServeLogs.record(attrs(recipient))
    :ok = WidgetServeLogs.record(attrs(recipient))

    assert [%{connect_count: 3}] = Repo.all(WidgetServeLog)
  end

  test "a new page id is a new load", %{recipient: recipient} do
    :ok = WidgetServeLogs.record(attrs(recipient))
    :ok = WidgetServeLogs.record(attrs(recipient, %{page_load_id: Ecto.UUID.generate()}))

    assert Repo.aggregate(WidgetServeLog, :count) == 2
  end

  test "a malformed sync_id is stored as nil and each load is its own row", %{
    recipient: recipient
  } do
    :ok = WidgetServeLogs.record(attrs(recipient, %{page_load_id: "not-a-uuid"}))
    :ok = WidgetServeLogs.record(attrs(recipient, %{page_load_id: "not-a-uuid"}))

    logs = Repo.all(WidgetServeLog)
    assert length(logs) == 2
    assert Enum.all?(logs, &is_nil(&1.page_load_id))
  end

  test "a non-http host_url is dropped", %{recipient: recipient} do
    for url <- ["javascript:alert(1)", "ftp://files.example.com/x", "not a url", nil] do
      :ok = WidgetServeLogs.record(attrs(recipient, %{host_page_url: url, page_load_id: nil}))
    end

    logs = Repo.all(WidgetServeLog)
    assert length(logs) == 4
    assert Enum.all?(logs, &(is_nil(&1.host_page_url) and is_nil(&1.host)))
  end

  test "a long host_url is truncated", %{recipient: recipient} do
    url = "https://news.example.com/" <> String.duplicate("a", 3_000)
    :ok = WidgetServeLogs.record(attrs(recipient, %{host_page_url: url}))

    assert [%{host_page_url: stored}] = Repo.all(WidgetServeLog)
    assert String.length(stored) == 2048
  end

  test "an invalid load is not stored and still returns :ok", %{recipient: recipient} do
    assert :ok = WidgetServeLogs.record(attrs(recipient, %{ip_address: {203, 0, 113, 9}}))
    assert Repo.aggregate(WidgetServeLog, :count) == 0
  end

  test "prune deletes only rows past the retention window", %{recipient: recipient} do
    :ok = WidgetServeLogs.record(attrs(recipient))
    :ok = WidgetServeLogs.record(attrs(recipient, %{page_load_id: Ecto.UUID.generate()}))

    [old | _] = Repo.all(WidgetServeLog)
    old_at = NaiveDateTime.add(NaiveDateTime.utc_now(), -181 * 86_400, :second)
    Repo.update!(Ecto.Changeset.change(old, created_at: NaiveDateTime.truncate(old_at, :second)))

    assert WidgetServeLogs.prune(180, 1) == 1
    assert [remaining] = Repo.all(WidgetServeLog)
    refute remaining.id == old.id
  end

  describe "UserAgent" do
    test "bot?/1 flags automation and missing agents" do
      for ua <- [
            nil,
            "",
            "curl/8.4.0",
            "python-requests/2.31",
            "Googlebot/2.1",
            "HeadlessChrome/120"
          ] do
        assert UserAgent.bot?(ua), "expected #{inspect(ua)} to be a bot"
      end

      refute UserAgent.bot?(@chrome)
      refute UserAgent.bot?(@iphone)
    end

    test "classify/1 sorts real browsers into device classes" do
      assert %{browser: "Safari", device: "Mobile", platform: "iOS"} = UserAgent.classify(@iphone)
      assert %{browser: "Bot", device: "Bot"} = UserAgent.classify("curl/8.4.0")
      assert %{browser: nil, device: nil, platform: nil} = UserAgent.classify(nil)
    end
  end
end
