defmodule Qlarius.Sponster.WidgetServeReportingTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Sponster.WidgetServeLog
  alias Qlarius.Sponster.WidgetServeReporting, as: Reporting

  @chrome "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"

  setup do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    # The start of a 10-minute burst slot, an hour back, so every row in a
    # burst lands in the same slot and the same clock hour.
    slot_start = div(to_unix(now) - 3_600, 3_600) * 3_600

    %{
      recipient: recipient!("Reporting publisher"),
      base: slot_start |> DateTime.from_unix!() |> DateTime.to_naive(),
      range: {NaiveDateTime.add(now, -86_400, :second), NaiveDateTime.add(now, 60, :second)}
    }
  end

  defp to_unix(naive), do: naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

  defp recipient!(name) do
    owner =
      Repo.insert!(%Qlarius.Accounts.User{
        alias: "rep-owner-#{System.unique_integer([:positive])}"
      })

    Repo.insert!(%Recipient{
      user_id: owner.id,
      name: name,
      split_code: Ecto.UUID.generate(),
      referral_code: "rep-#{System.unique_integer([:positive])}"
    })
  end

  defp insert_logs!(count, fun) do
    rows =
      for i <- 1..count do
        Map.merge(
          %{
            authed: false,
            connect_count: 1,
            user_agent: @chrome,
            host: "news.example.com",
            host_page_url: "https://news.example.com/",
            page_load_id: Ecto.UUID.generate(),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          },
          fun.(i)
        )
      end

    Repo.insert_all(WidgetServeLog, rows)
  end

  defp kinds(range, filters),
    do: range |> Reporting.suspicious(filters) |> Enum.map(& &1.kind) |> Enum.uniq()

  test "kpis count loads, pages, reconnects, and signed-in share", ctx do
    insert_logs!(4, fn i ->
      %{
        recipient_id: ctx.recipient.id,
        ip_address: "198.51.100.#{rem(i, 2)}",
        authed: i == 1,
        connect_count: if(i == 1, do: 3, else: 1),
        created_at: ctx.base
      }
    end)

    insert_logs!(1, fn _ ->
      %{
        recipient_id: ctx.recipient.id,
        ip_address: "198.51.100.9",
        host: nil,
        host_page_url: nil,
        created_at: ctx.base
      }
    end)

    kpis = Reporting.kpis(ctx.range, %{recipient_id: ctx.recipient.id})

    assert kpis.loads == 5
    assert kpis.reconnects == 2
    assert kpis.unique_pages == 5
    assert kpis.unique_ips == 3
    assert kpis.authed == 1
    assert kpis.authed_share == 0.2
    assert kpis.direct_opens == 1
    assert kpis.flagged == 1
  end

  test "time_series fills empty buckets and splits signed-in loads", ctx do
    insert_logs!(2, fn i ->
      %{
        recipient_id: ctx.recipient.id,
        ip_address: "198.51.100.1",
        authed: i == 1,
        created_at: ctx.base
      }
    end)

    series = Reporting.time_series(ctx.range, :hour, %{recipient_id: ctx.recipient.id})

    assert length(series) >= 24

    assert %{authed: 1, anon: 1, total: 2} =
             Enum.find(series, &(NaiveDateTime.compare(&1.at, ctx.base) == :eq))

    assert Enum.sum(Enum.map(series, & &1.total)) == 2
  end

  test "by_recipient and by_host aggregate per publisher", ctx do
    other = recipient!("Other publisher")

    insert_logs!(3, fn i ->
      %{recipient_id: ctx.recipient.id, ip_address: "198.51.100.#{i}", created_at: ctx.base}
    end)

    insert_logs!(1, fn _ ->
      %{
        recipient_id: other.id,
        ip_address: "198.51.100.1",
        host: "blog.example.org",
        created_at: ctx.base
      }
    end)

    rows = Reporting.by_recipient(ctx.range)
    mine = Enum.find(rows, &(&1.recipient_id == ctx.recipient.id))
    assert %{name: "Reporting publisher", loads: 3, unique_ips: 3, loads_per_ip: 1.0} = mine

    hosts = Reporting.by_host(ctx.range)
    assert %{loads: 3, recipients: 1} = Enum.find(hosts, &(&1.host == "news.example.com"))
    assert %{loads: 1} = Enum.find(hosts, &(&1.host == "blog.example.org"))
  end

  describe "suspicious rules" do
    test "burst flags more than 30 loads from one IP in 10 minutes", ctx do
      insert_logs!(31, fn i ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.1",
          created_at: NaiveDateTime.add(ctx.base, i, :second)
        }
      end)

      insert_logs!(30, fn i ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.2",
          created_at: NaiveDateTime.add(ctx.base, i, :second)
        }
      end)

      assert :burst in kinds(ctx.range, %{ip: "192.0.2.1"})
      refute :burst in kinds(ctx.range, %{ip: "192.0.2.2"})

      [entry] =
        Enum.filter(Reporting.suspicious(ctx.range, %{ip: "192.0.2.1"}), &(&1.kind == :burst))

      assert entry.count == 31
      assert entry.filter == %{ip: "192.0.2.1", recipient_id: ctx.recipient.id}
    end

    test "page_id_churn flags more than 10 page ids from one IP in an hour", ctx do
      # Spread across 50 minutes so the 10-minute burst rule stays quiet.
      insert_logs!(11, fn i ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.10",
          created_at: NaiveDateTime.add(ctx.base, i * 270, :second)
        }
      end)

      insert_logs!(10, fn i ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.11",
          created_at: NaiveDateTime.add(ctx.base, i * 270, :second)
        }
      end)

      assert kinds(ctx.range, %{ip: "192.0.2.10"}) == [:page_id_churn]
      assert kinds(ctx.range, %{ip: "192.0.2.11"}) == []
    end

    test "shared_page_id flags one page id seen from more than 3 IPs", ctx do
      shared = Ecto.UUID.generate()
      quiet = Ecto.UUID.generate()

      for {page_id, ips} <- [{shared, 4}, {quiet, 3}], i <- 1..ips do
        insert_logs!(1, fn _ ->
          %{
            recipient_id: recipient!("Shared #{i}").id,
            ip_address: "192.0.2.#{20 + i}",
            page_load_id: page_id,
            created_at: ctx.base
          }
        end)
      end

      assert kinds(ctx.range, %{page_load_id: shared}) == [:shared_page_id]
      assert kinds(ctx.range, %{page_load_id: quiet}) == []
    end

    test "reconnect_storm flags more than 20 connects on one load", ctx do
      insert_logs!(1, fn _ ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.30",
          connect_count: 21,
          created_at: ctx.base
        }
      end)

      insert_logs!(1, fn _ ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.31",
          connect_count: 20,
          created_at: ctx.base
        }
      end)

      assert kinds(ctx.range, %{ip: "192.0.2.30"}) == [:reconnect_storm]
      assert kinds(ctx.range, %{ip: "192.0.2.31"}) == []
    end

    test "bot_agent flags automation agents and embed loads with no agent", ctx do
      insert_logs!(1, fn _ ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.40",
          user_agent: "curl/8.4.0",
          created_at: ctx.base
        }
      end)

      insert_logs!(1, fn _ ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.41",
          user_agent: nil,
          created_at: ctx.base
        }
      end)

      insert_logs!(1, fn _ ->
        %{recipient_id: ctx.recipient.id, ip_address: "192.0.2.42", created_at: ctx.base}
      end)

      assert kinds(ctx.range, %{ip: "192.0.2.40"}) == [:bot_agent]
      assert kinds(ctx.range, %{ip: "192.0.2.41"}) == [:bot_agent]
      assert kinds(ctx.range, %{ip: "192.0.2.42"}) == []
    end

    test "bad_host flags missing and Qadabra hosts", ctx do
      insert_logs!(1, fn _ ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.50",
          host: nil,
          host_page_url: nil,
          created_at: ctx.base
        }
      end)

      insert_logs!(1, fn _ ->
        %{
          recipient_id: ctx.recipient.id,
          ip_address: "192.0.2.51",
          host: "qadabra.app",
          created_at: ctx.base
        }
      end)

      insert_logs!(1, fn _ ->
        %{recipient_id: ctx.recipient.id, ip_address: "192.0.2.52", created_at: ctx.base}
      end)

      assert kinds(ctx.range, %{ip: "192.0.2.50"}) == [:bad_host]
      assert kinds(ctx.range, %{ip: "192.0.2.51"}) == [:bad_host]
      assert kinds(ctx.range, %{ip: "192.0.2.52"}) == []
    end
  end

  test "recent filters by flag and pages newest first", ctx do
    insert_logs!(3, fn i ->
      %{
        recipient_id: ctx.recipient.id,
        ip_address: "192.0.2.60",
        user_agent: if(i == 3, do: "curl/8.4.0", else: @chrome),
        created_at: NaiveDateTime.add(ctx.base, i, :second)
      }
    end)

    assert %{total: 1, rows: [%{flags: [:bot_agent]}]} =
             Reporting.recent(ctx.range, %{ip: "192.0.2.60", flag: :bot_agent})

    page_two = Reporting.recent(ctx.range, %{ip: "192.0.2.60"}, 2, 2)
    assert page_two.total == 3
    assert [%{created_at: oldest}] = page_two.rows
    assert NaiveDateTime.compare(oldest, NaiveDateTime.add(ctx.base, 1, :second)) == :eq
  end
end
