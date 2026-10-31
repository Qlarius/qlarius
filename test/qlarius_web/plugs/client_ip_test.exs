defmodule QlariusWeb.Plugs.ClientIpTest do
  # Toggles :trust_proxy_ip_headers application env.
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias QlariusWeb.Plugs.ClientIp

  setup do
    previous = Application.get_env(:qlarius, :trust_proxy_ip_headers)
    Application.put_env(:qlarius, :trust_proxy_ip_headers, true)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:qlarius, :trust_proxy_ip_headers)
        value -> Application.put_env(:qlarius, :trust_proxy_ip_headers, value)
      end
    end)

    :ok
  end

  defp call(headers) do
    conn = conn(:get, "/")
    conn = Enum.reduce(headers, conn, fn {k, v}, c -> put_req_header(c, k, v) end)
    ClientIp.call(conn, ClientIp.init([]))
  end

  test "prefers cf-connecting-ip" do
    conn = call([{"cf-connecting-ip", "203.0.113.9"}, {"x-forwarded-for", "198.51.100.1"}])
    assert conn.remote_ip == {203, 0, 113, 9}
  end

  test "falls back to the first x-forwarded-for entry" do
    conn = call([{"x-forwarded-for", "198.51.100.1, 10.0.0.2"}])
    assert conn.remote_ip == {198, 51, 100, 1}
  end

  test "accepts IPv6" do
    conn = call([{"cf-connecting-ip", "2001:db8::1"}])
    assert conn.remote_ip == {8193, 3512, 0, 0, 0, 0, 0, 1}
  end

  test "leaves remote_ip alone for unparseable or missing headers" do
    original = conn(:get, "/").remote_ip
    assert call([{"x-forwarded-for", "not-an-ip"}]).remote_ip == original
    assert call([]).remote_ip == original
  end

  test "is a no-op when proxy headers are not trusted" do
    Application.put_env(:qlarius, :trust_proxy_ip_headers, false)
    original = conn(:get, "/").remote_ip
    assert call([{"cf-connecting-ip", "203.0.113.9"}]).remote_ip == original
  end
end
