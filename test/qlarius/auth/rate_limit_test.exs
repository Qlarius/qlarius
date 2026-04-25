defmodule Qlarius.Auth.RateLimitTest do
  # No DB, pure ETS-backed Hammer checks, so no DataCase. We opt back
  # into the master flag per-test via `Application.put_env/3` since
  # `config/test.exs` disables it globally.
  use ExUnit.Case, async: false

  alias Qlarius.Auth.RateLimit

  setup do
    prev = Application.get_env(:qlarius, :auth_rate_limit, [])
    Application.put_env(:qlarius, :auth_rate_limit, enabled?: true)

    on_exit(fn ->
      Application.put_env(:qlarius, :auth_rate_limit, prev)
    end)

    # Hammer's ETS backend persists buckets across tests; give each
    # test a unique phone/ip tag so the 3-per-window / 10-per-window
    # counters start fresh.
    tag = System.unique_integer([:positive])
    %{phone: "+1555#{tag}", ip: "10.0.#{rem(tag, 250)}.#{rem(tag, 200)}"}
  end

  describe "check_send_code_per_phone/1" do
    test "allows the first three attempts, denies the fourth", %{phone: phone} do
      for _ <- 1..3 do
        assert :ok = RateLimit.check_send_code_per_phone(phone)
      end

      assert {:error, {:rate_limited, retry_after}} =
               RateLimit.check_send_code_per_phone(phone)

      assert retry_after == 10 * 60
    end

    test "different phones have independent buckets", %{phone: phone} do
      other = phone <> "9"

      for _ <- 1..3, do: assert(:ok = RateLimit.check_send_code_per_phone(phone))
      assert :ok = RateLimit.check_send_code_per_phone(other)
    end

    test "nil/empty phone is a no-op (defensive)" do
      assert :ok = RateLimit.check_send_code_per_phone(nil)
      assert :ok = RateLimit.check_send_code_per_phone("")
    end
  end

  describe "check_send_code_per_ip/1" do
    test "allows the first ten attempts, denies the eleventh", %{ip: ip} do
      for _ <- 1..10 do
        assert :ok = RateLimit.check_send_code_per_ip(ip)
      end

      assert {:error, {:rate_limited, retry_after}} = RateLimit.check_send_code_per_ip(ip)
      assert retry_after == 60 * 60
    end

    test "skips unknown IPs (0.0.0.0 / nil / empty)" do
      for _ <- 1..50 do
        assert :ok = RateLimit.check_send_code_per_ip("0.0.0.0")
        assert :ok = RateLimit.check_send_code_per_ip(nil)
        assert :ok = RateLimit.check_send_code_per_ip("")
      end
    end
  end

  describe "check_finalize_per_ip/1" do
    test "allows twenty attempts, denies the twenty-first", %{ip: ip} do
      for _ <- 1..20 do
        assert :ok = RateLimit.check_finalize_per_ip(ip)
      end

      assert {:error, {:rate_limited, _}} = RateLimit.check_finalize_per_ip(ip)
    end
  end

  describe "enabled? short-circuit" do
    test "when disabled, all gates return :ok indefinitely", %{phone: phone, ip: ip} do
      Application.put_env(:qlarius, :auth_rate_limit, enabled?: false)

      for _ <- 1..100 do
        assert :ok = RateLimit.check_send_code_per_phone(phone)
        assert :ok = RateLimit.check_send_code_per_ip(ip)
        assert :ok = RateLimit.check_finalize_per_ip(ip)
      end
    end
  end

  describe "format_ip/1" do
    test "tuples" do
      assert RateLimit.format_ip({127, 0, 0, 1}) == "127.0.0.1"
      assert RateLimit.format_ip({0, 0, 0, 0, 0, 0, 0, 1}) == "::1"
    end

    test "passes binaries through" do
      assert RateLimit.format_ip("1.2.3.4") == "1.2.3.4"
    end

    test "nil" do
      assert RateLimit.format_ip(nil) == nil
    end
  end
end
