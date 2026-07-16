defmodule Qlarius.Qai.Economics do
  @moduledoc """
  Aggregations over measured Qai usage for pricing decisions.

  Reads `qai_messages.usage` (provider token counts, summed per turn across
  tool rounds) plus the suggestion queue, and prices token classes with
  cache-aware rates: uncached input at the input rate, cache writes at 1.25x,
  cache reads at 0.1x, output at the output rate.

  Honesty rules for the dashboard: costs are always labeled estimates (rates
  are inputs, not billing data), stopped or failed turns carry no usage and
  are counted separately as unmeasured rather than silently averaged in, and
  fleeting sessions hard-delete after expiry, so windows longer than the
  fleeting window only cover preserved sessions plus messages' lifetime -
  the per-day series is the reliable shape, totals are floors.
  """

  import Ecto.Query

  alias Qlarius.MeCP.Suggestions.TagSuggestion
  alias Qlarius.Qai.{Message, Session}
  alias Qlarius.Repo

  @default_rates %{
    frontier: %{input: 3.00, output: 15.00},
    cheap: %{input: 1.00, output: 5.00}
  }

  def default_rates, do: @default_rates

  defmacrop usage_tokens(message, key) do
    quote do
      fragment("COALESCE((? ->> ?)::bigint, 0)", unquote(message).usage, unquote(key))
    end
  end

  @doc """
  Totals for assistant turns in the window: token sums by class, distinct
  sessions and MeFiles, turn counts, and how many turns carry no usage
  (stopped or failed streams).
  """
  def totals(days) do
    row =
      Repo.one(
        from m in Message,
          join: s in Session,
          on: s.id == m.qai_session_id,
          where: m.role == "assistant" and m.inserted_at >= ago(^days, "day"),
          select: %{
            turns: count(m.id),
            unmeasured:
              fragment("COUNT(*) FILTER (WHERE ? = '{}' OR ? IS NULL)", m.usage, m.usage),
            sessions: count(m.qai_session_id, :distinct),
            me_files: count(s.me_file_id, :distinct),
            input: sum(usage_tokens(m, "input_tokens")),
            output: sum(usage_tokens(m, "output_tokens")),
            cache_read: sum(usage_tokens(m, "cache_read_input_tokens")),
            cache_write: sum(usage_tokens(m, "cache_creation_input_tokens"))
          }
      )

    zero_nils(row)
  end

  @doc "Per-day series, oldest first: turn/session counts and token sums by class."
  def daily_series(days) do
    Repo.all(
      from m in Message,
        where: m.role == "assistant" and m.inserted_at >= ago(^days, "day"),
        group_by: fragment("date(?)", m.inserted_at),
        order_by: fragment("date(?)", m.inserted_at),
        select: %{
          day: fragment("date(?)", m.inserted_at),
          turns: count(m.id),
          sessions: count(m.qai_session_id, :distinct),
          input: sum(usage_tokens(m, "input_tokens")),
          output: sum(usage_tokens(m, "output_tokens")),
          cache_read: sum(usage_tokens(m, "cache_read_input_tokens")),
          cache_write: sum(usage_tokens(m, "cache_creation_input_tokens"))
        }
    )
    |> Enum.map(&zero_nils/1)
  end

  @doc "Token sums and turn counts grouped by serving model."
  def model_breakdown(days) do
    Repo.all(
      from m in Message,
        where:
          m.role == "assistant" and m.inserted_at >= ago(^days, "day") and
            not is_nil(m.model),
        group_by: m.model,
        order_by: [desc: count(m.id)],
        select: %{
          model: m.model,
          turns: count(m.id),
          input: sum(usage_tokens(m, "input_tokens")),
          output: sum(usage_tokens(m, "output_tokens")),
          cache_read: sum(usage_tokens(m, "cache_read_input_tokens")),
          cache_write: sum(usage_tokens(m, "cache_creation_input_tokens"))
        }
    )
    |> Enum.map(&zero_nils/1)
  end

  @doc """
  Estimated cost distribution across sessions in the window (each session's
  turns summed and priced). Returns `%{count:, p50:, p90:, max:}` in USD.
  The spread is the pricing question: a flat session price must clear p90,
  not the mean, or heavy sessions invert the margin.
  """
  def session_cost_distribution(days, rates \\ @default_rates) do
    costs =
      Repo.all(
        from m in Message,
          where: m.role == "assistant" and m.inserted_at >= ago(^days, "day"),
          group_by: m.qai_session_id,
          select: %{
            model: max(m.model),
            input: sum(usage_tokens(m, "input_tokens")),
            output: sum(usage_tokens(m, "output_tokens")),
            cache_read: sum(usage_tokens(m, "cache_read_input_tokens")),
            cache_write: sum(usage_tokens(m, "cache_creation_input_tokens"))
          }
      )
      |> Enum.map(fn row -> row |> zero_nils() |> cost(rates) end)
      |> Enum.sort()

    case costs do
      [] -> %{count: 0, p50: 0.0, p90: 0.0, max: 0.0}
      _ -> %{count: length(costs), p50: percentile(costs, 0.50), p90: percentile(costs, 0.90), max: List.last(costs)}
    end
  end

  @doc """
  Cache-aware estimated cost in USD for a token-sum row. Model tier is
  inferred from the row's `:model` when present ("haiku" means cheap tier);
  rows without one price at frontier rates, the conservative choice.
  """
  def cost(row, rates \\ @default_rates) do
    tier = tier_for(row[:model])
    input_rate = rates[tier].input / 1.0e6
    output_rate = rates[tier].output / 1.0e6

    row.input * input_rate +
      row.cache_write * input_rate * 1.25 +
      row.cache_read * input_rate * 0.1 +
      row.output * output_rate
  end

  @doc """
  What the same input volume would have cost with no cache: reads and writes
  repriced as plain input. The delta is the measured caching win.
  """
  def uncached_cost(row, rates \\ @default_rates) do
    tier = tier_for(row[:model])
    input_rate = rates[tier].input / 1.0e6
    output_rate = rates[tier].output / 1.0e6

    (row.input + row.cache_write + row.cache_read) * input_rate + row.output * output_rate
  end

  @doc "Share of context tokens served from cache, 0.0-1.0."
  def cache_hit_share(%{input: input, cache_read: cache_read, cache_write: cache_write}) do
    context = input + cache_read + cache_write
    if context > 0, do: cache_read / context, else: 0.0
  end

  @doc """
  Suggestion-loop conversion per client in the window: filed, accepted,
  dismissed, pending, and acceptance rate over resolved. The value-side
  metric from the build plan - each accepted suggestion is MeFile density
  the session produced beyond its inference margin.
  """
  def suggestion_conversion(days) do
    Repo.all(
      from sg in TagSuggestion,
        join: g in assoc(sg, :grant),
        join: c in assoc(g, :mecp_client),
        where: sg.inserted_at >= ago(^days, "day"),
        group_by: c.name,
        order_by: [desc: count(sg.id)],
        select: %{
          client: c.name,
          filed: count(sg.id),
          accepted: fragment("COUNT(*) FILTER (WHERE ? = 'accepted')", sg.status),
          dismissed: fragment("COUNT(*) FILTER (WHERE ? = 'dismissed')", sg.status),
          pending: fragment("COUNT(*) FILTER (WHERE ? = 'pending')", sg.status)
        }
    )
    |> Enum.map(fn row ->
      resolved = row.accepted + row.dismissed
      rate = if resolved > 0, do: row.accepted / resolved, else: nil
      Map.put(row, :acceptance_rate, rate)
    end)
  end

  defp tier_for(model) when is_binary(model) do
    if String.contains?(model, "haiku"), do: :cheap, else: :frontier
  end

  defp tier_for(_), do: :frontier

  defp percentile(sorted, p) do
    index = min(round(p * length(sorted)) |> max(1), length(sorted)) - 1
    Enum.at(sorted, index)
  end

  @token_keys [:input, :output, :cache_read, :cache_write]

  # SUM(bigint) comes back from Postgres as a Decimal; the empty window as nil.
  defp zero_nils(nil), do: nil

  defp zero_nils(row) do
    Map.new(row, fn
      {key, nil} when key in @token_keys -> {key, 0}
      {key, %Decimal{} = d} when key in @token_keys -> {key, Decimal.to_integer(d)}
      pair -> pair
    end)
  end
end
