defmodule Qlarius.AdminApi.SafeFetchTest do
  use ExUnit.Case, async: true

  alias Qlarius.AdminApi.SafeFetch

  @png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8,
         2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 255, 255,
         63, 0, 5, 254, 2, 254, 167, 53, 129, 132, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>

  test "rejects urls that are not https and hosts that are not public" do
    assert SafeFetch.fetch("http://cdn.test/banner.png") == {:error, :image_not_https}
    assert SafeFetch.fetch("https://127.0.0.1/banner.png") == {:error, :image_host_blocked}
    assert SafeFetch.fetch("https://169.254.169.254/latest") == {:error, :image_host_blocked}
  end

  test "public_address? blocks loopback, private, link-local, multicast, and mapped ipv4" do
    refute SafeFetch.public_address?({127, 0, 0, 1})
    refute SafeFetch.public_address?({10, 1, 1, 1})
    refute SafeFetch.public_address?({192, 168, 1, 1})
    refute SafeFetch.public_address?({169, 254, 1, 1})
    refute SafeFetch.public_address?({0, 0, 0, 0, 0, 0, 0, 1})
    refute SafeFetch.public_address?({0, 0, 0, 0, 0, 0xFFFF, 127 * 256, 1})
    assert SafeFetch.public_address?({8, 8, 8, 8})
  end

  test "fetch_bytes accepts a png and rejects other bytes" do
    assert {:ok, %{ext: "png"}} = SafeFetch.fetch_bytes(@png)
    assert SafeFetch.fetch_bytes("not an image") == {:error, :image_type_rejected}
  end

  test "re-checks each redirect and refuses a private hop" do
    plug = fn conn ->
      [host | _] = Plug.Conn.get_req_header(conn, "host")

      case host do
        "cdn.test" ->
          conn
          |> Plug.Conn.put_resp_header("location", "https://secret.test/banner.png")
          |> Plug.Conn.send_resp(302, "")

        "ok.test" ->
          Plug.Conn.send_resp(conn, 200, @png)
      end
    end

    resolve = fn
      "cdn.test" -> {:ok, [{8, 8, 8, 8}]}
      "secret.test" -> {:ok, [{127, 0, 0, 1}]}
      "ok.test" -> {:ok, [{1, 1, 1, 1}]}
    end

    assert SafeFetch.fetch("https://cdn.test/banner.png", plug: plug, resolve: resolve) ==
             {:error, :image_host_blocked}

    assert {:ok, %{ext: "png"}} =
             SafeFetch.fetch("https://ok.test/banner.png", plug: plug, resolve: resolve)
  end
end
