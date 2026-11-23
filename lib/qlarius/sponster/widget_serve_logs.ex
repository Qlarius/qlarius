defmodule Qlarius.Sponster.WidgetServeLogs do
  @moduledoc """
  Records loads of the third-party Sponster bar.
  """

  require Logger
  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.WidgetServeLog
  alias Qlarius.Sponster.WidgetServeLogs.UserAgent

  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  @max_url 2048
  @retention_days 180

  @doc """
  Records one bar load. Never raises: a logging failure must not break the
  widget, so errors are logged and `:ok` is returned either way.

  A reconnect from the same host page (same `page_load_id`) increments
  `connect_count` on the existing row instead of adding a load.
  """
  def record(attrs) do
    attrs = normalize(attrs)
    changeset = WidgetServeLog.changeset(%WidgetServeLog{}, attrs)

    result =
      if attrs.page_load_id do
        Repo.insert(changeset,
          on_conflict: [
            inc: [connect_count: 1],
            set: [updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)]
          ],
          conflict_target:
            {:unsafe_fragment, "(page_load_id, recipient_id) WHERE page_load_id IS NOT NULL"}
        )
      else
        Repo.insert(changeset)
      end

    case result do
      {:ok, _} -> :ok
      {:error, reason} -> log_failure(reason)
    end
  rescue
    error -> log_failure(error)
  end

  @doc """
  Deletes rows older than `days`, in batches so one run never holds a long
  lock on a busy table. Returns the number of rows deleted.
  """
  def prune(days \\ @retention_days, batch_size \\ 5_000) do
    cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -days * 86_400, :second)
    prune_batches(cutoff, batch_size, 0)
  end

  defp prune_batches(cutoff, batch_size, total) do
    ids =
      from(l in WidgetServeLog,
        where: l.created_at < ^cutoff,
        select: l.id,
        limit: ^batch_size
      )

    {deleted, _} = Repo.delete_all(from(l in WidgetServeLog, where: l.id in subquery(ids)))

    if deleted < batch_size,
      do: total + deleted,
      else: prune_batches(cutoff, batch_size, total + deleted)
  end

  defp log_failure(reason) do
    Logger.warning("WidgetServeLogs: could not record load: #{inspect(reason)}")
    :ok
  end

  defp normalize(attrs) do
    attrs = Map.new(attrs)
    url = http_url(attrs[:host_page_url])
    ua = blank_to_nil(attrs[:user_agent])

    attrs
    |> Map.put(:page_load_id, page_load_id(attrs[:page_load_id]))
    |> Map.put(:host_page_url, url && String.slice(url, 0, @max_url))
    |> Map.put(:host, host(url))
    |> Map.put(:user_agent, ua)
    |> Map.merge(UserAgent.classify(ua))
  end

  defp page_load_id(id) when is_binary(id) do
    if Regex.match?(@uuid, id), do: String.downcase(id), else: nil
  end

  defp page_load_id(_), do: nil

  defp http_url(url) when is_binary(url) do
    case URI.parse(String.trim(url)) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        String.trim(url)

      _ ->
        nil
    end
  end

  defp http_url(_), do: nil

  defp host(nil), do: nil

  defp host(url),
    do: url |> URI.parse() |> Map.get(:host) |> String.downcase() |> String.slice(0, 255)

  defp blank_to_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp blank_to_nil(_), do: nil
end
