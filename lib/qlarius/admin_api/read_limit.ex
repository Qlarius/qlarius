defmodule Qlarius.AdminApi.ReadLimit do
  @moduledoc false

  # Stops one admin token from holding every Repo connection. The production
  # pool is small and shared with Oban, and a client that fans out GETs fills it.

  @table :admin_api_read_slots
  @window_ms 60_000
  @default_limit 60
  @default_concurrency 4

  def check(raw, opts \\ []) when is_binary(raw) do
    key = key(raw)
    limit = Keyword.get(opts, :limit, configured(:admin_api_read_limit, @default_limit))

    case Hammer.check_rate(rate_key(key), @window_ms, limit) do
      {:allow, _} ->
        case acquire(key, opts) do
          :ok -> :ok
          :busy -> {:error, :rate_limited}
        end

      {:deny, _} ->
        {:error, :rate_limited}
    end
  end

  def release(raw) when is_binary(raw) do
    ensure_table()
    :ets.update_counter(@table, key(raw), {2, -1, 0, 0}, {key(raw), 0})
    :ok
  end

  defp acquire(key, opts) do
    ensure_table()

    max =
      Keyword.get(
        opts,
        :concurrency,
        configured(:admin_api_read_concurrency, @default_concurrency)
      )

    count = :ets.update_counter(@table, key, {2, 1}, {key, 0})

    if count > max do
      :ets.update_counter(@table, key, {2, -1, 0, 0}, {key, 0})
      :busy
    else
      :ok
    end
  end

  defp rate_key(key), do: "admin_api_read:" <> key

  defp key(raw) do
    :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
  end

  defp configured(name, default) do
    Process.get(name) || Application.get_env(:qlarius, name, default)
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set])
        rescue
          ArgumentError -> @table
        end

      _tid ->
        @table
    end
  end
end
