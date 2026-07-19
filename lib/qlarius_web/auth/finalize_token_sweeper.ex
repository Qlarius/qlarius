defmodule QlariusWeb.Auth.FinalizeTokenSweeper do
  @moduledoc """
  Owns the ETS table that backs `QlariusWeb.Auth.FinalizeToken`'s
  single-use `jti` guard, and periodically evicts expired entries so the
  table stays bounded.

  The sweep interval is half the token TTL (rounded up), which keeps the
  worst-case table size at roughly `max_burst_rate * ttl`.
  """

  use GenServer

  alias QlariusWeb.Auth.ExtensionIdentityToken
  alias QlariusWeb.Auth.FinalizeToken

  @sweep_interval_ms :timer.seconds(30)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Owns both finalize single-use jtis and extension-identity revoke jtis.
    # `:public` lets request processes insert; modules only read/insert.
    tables = [FinalizeToken.jti_table(), ExtensionIdentityToken.jti_table()]
    Enum.each(tables, &ensure_table/1)

    schedule_sweep()
    {:ok, %{tables: tables}}
  end

  @impl true
  def handle_info(:sweep, %{tables: tables} = state) do
    now = System.system_time(:second)

    # Match spec: {_jti, expires_at} where expires_at <= now -> true (delete)
    match_spec = [{{:_, :"$1"}, [{:"=<", :"$1", now}], [true]}]
    Enum.each(tables, &:ets.select_delete(&1, match_spec))

    schedule_sweep()
    {:noreply, state}
  end

  defp ensure_table(table) do
    case :ets.whereis(table) do
      :undefined ->
        :ets.new(table, [:set, :public, :named_table, read_concurrency: true])

      _ref ->
        :ok
    end
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval_ms)
  end
end
