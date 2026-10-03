defmodule Qlarius.AdminApi.Idempotent do
  @moduledoc """
  Find-or-create by `api_ref` for admin API creates.

  A create with a new key inserts. A create with a known key returns the
  existing row as matched, with the requested fields that differ from it, and
  only changes the row when the caller sends `on_existing: "update"`.

  Options:

    * `:fields` - the request fields compared for `differences`
    * `:preview` - `fn attrs -> {:ok, preview} | {:error, reason}`, used by dry runs
    * `:insert` - `fn attrs -> {:ok, record} | {:error, reason}`
    * `:update` - `fn record, attrs -> {:ok, record} | {:error, reason}`
    * `:owned?` - `fn record -> boolean`, false when the key belongs to another owner
    * `:locked` - `fn record -> nil | reason`, refuses `on_existing: "update"`
    * `:dry_run` and `:on_existing` - from the request
  """

  alias Qlarius.{ApiRef, Repo}

  def create(schema, params, opts) do
    ref = params["api_ref"]

    cond do
      ref in [nil, ""] -> {:error, :api_ref_required}
      not ApiRef.valid?(ref) -> {:error, :invalid_api_ref}
      existing = Repo.get_by(schema, api_ref: ref) -> existing(existing, params, opts)
      opts[:dry_run] -> preview(params, opts)
      true -> insert(params, opts)
    end
  end

  defp preview(params, opts) do
    with {:ok, preview} <- opts[:preview].(params) do
      {:ok, %{result: "would_create", record: preview, differences: %{}}}
    end
  end

  defp insert(params, opts) do
    with {:ok, record} <- opts[:insert].(params) do
      {:ok, %{result: "created", record: record, differences: %{}}}
    end
  end

  defp existing(record, params, opts) do
    owned? = Keyword.get(opts, :owned?, fn _ -> true end)

    if owned?.(record) do
      extra = extra_differences(record, opts)
      differences = Map.merge(differences(record, params, Keyword.fetch!(opts, :fields)), extra)
      on_existing(opts[:on_existing], record, params, differences, opts)
    else
      {:error, {:api_ref_conflict, params["api_ref"]}}
    end
  end

  defp on_existing(value, record, _params, differences, _opts) when value in [nil, "", "skip"] do
    {:ok, %{result: "matched", record: record, differences: differences}}
  end

  defp on_existing("update", record, _params, differences, _opts) when differences == %{} do
    {:ok, %{result: "matched", record: record, differences: differences}}
  end

  defp on_existing("update", record, params, differences, opts) do
    locked = Keyword.get(opts, :locked, fn _ -> nil end)

    cond do
      reason = locked.(record) ->
        {:error, reason}

      opts[:dry_run] ->
        preview_update(record, params, differences, opts)

      true ->
        attrs = Map.take(params, Map.keys(differences))

        with {:ok, updated} <- opts[:update].(record, attrs) do
          {:ok, %{result: "updated", record: updated, differences: differences}}
        end
    end
  end

  defp on_existing(_other, _record, _params, _differences, _opts),
    do: {:error, :invalid_on_existing}

  defp preview_update(record, params, differences, opts) do
    case opts[:preview_update] do
      fun when is_function(fun, 3) ->
        fun.(record, Map.take(params, Map.keys(differences)), differences)

      _ ->
        {:ok, %{result: "would_update", record: record, differences: differences}}
    end
  end

  defp extra_differences(record, opts) do
    case opts[:extra_differences] do
      fun when is_function(fun, 1) -> fun.(record)
      _ -> %{}
    end
  end

  @doc """
  The requested fields whose values differ from the record, as
  `%{field => %{"current" => value, "requested" => value}}`.
  """
  def differences(record, params, fields) do
    fields
    |> Enum.filter(&Map.has_key?(params, &1))
    |> Enum.reduce(%{}, fn field, acc ->
      current = Map.get(record, String.to_existing_atom(field))
      requested = params[field]

      if normalize(current) == normalize(requested) do
        acc
      else
        Map.put(acc, field, %{"current" => current, "requested" => requested})
      end
    end)
  end

  defp normalize(nil), do: ""
  defp normalize(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp normalize(value) when is_binary(value), do: String.trim(value)
  defp normalize(value), do: to_string(value)
end
