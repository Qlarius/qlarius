defmodule Qlarius.AdminApi.ReadLimitTest do
  use ExUnit.Case, async: true

  alias Qlarius.AdminApi.ReadLimit

  test "a token can hold only the allowed number of reads" do
    raw = "read-slot-#{System.unique_integer([:positive])}"

    assert :ok = ReadLimit.check(raw, concurrency: 1, limit: 10)
    assert {:error, :rate_limited} = ReadLimit.check(raw, concurrency: 1, limit: 10)

    assert :ok = ReadLimit.release(raw)
    assert :ok = ReadLimit.check(raw, concurrency: 1, limit: 10)
    assert :ok = ReadLimit.release(raw)
  end

  test "reads past the window are rejected" do
    raw = "read-rate-#{System.unique_integer([:positive])}"

    assert :ok = ReadLimit.check(raw, concurrency: 10, limit: 2)
    assert :ok = ReadLimit.release(raw)
    assert :ok = ReadLimit.check(raw, concurrency: 10, limit: 2)
    assert :ok = ReadLimit.release(raw)
    assert {:error, :rate_limited} = ReadLimit.check(raw, concurrency: 10, limit: 2)
  end
end
