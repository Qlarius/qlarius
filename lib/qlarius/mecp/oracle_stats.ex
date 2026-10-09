defmodule Qlarius.MeCP.OracleStats do
  @moduledoc """
  Admin read model for the Qai Oracle page: MeCP activity over a window of
  days, built from the access log (every read already writes exactly one
  event: kind, response shape, grant, time) and the suggestion queue. Counts
  only; no content, values or answers are stored to report.
  """

  import Ecto.Query

  alias Qlarius.MeCP.AccessLog.AccessEvent
  alias Qlarius.MeCP.Clients.Client
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.Suggestions.TagSuggestion
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  @doc """
  Totals for the window: oracle reads split into asks and searches, capsule
  reads, suggestions filed, handshakes, and distinct grants and MeFiles.
  """
  def totals(days) do
    by_kind =
      Repo.all(
        from e in AccessEvent,
          where: e.occurred_at >= ^since(days),
          group_by: [e.kind, fragment("?->>'form'", e.response_shape)],
          select: {e.kind, fragment("?->>'form'", e.response_shape), count(e.id)}
      )

    count_where = fn pred ->
      by_kind |> Enum.filter(pred) |> Enum.map(&elem(&1, 2)) |> Enum.sum()
    end

    reach =
      Repo.one(
        from e in AccessEvent,
          where: e.occurred_at >= ^since(days),
          select: %{
            grants: count(e.mecp_grant_id, :distinct),
            me_files: fragment("COUNT(DISTINCT ?->>'me_file_id')", e.response_shape)
          }
      )

    %{
      asks: count_where.(fn {kind, form, _} -> kind == "oracle" and form != "search_traits" end),
      searches:
        count_where.(fn {kind, form, _} -> kind == "oracle" and form == "search_traits" end),
      capsules: count_where.(fn {kind, _, _} -> kind == "capsule" end),
      suggestions: count_where.(fn {kind, _, _} -> kind == "suggestion" end),
      handshakes: count_where.(fn {kind, _, _} -> kind == "handshake" end),
      grants: reach.grants,
      me_files: reach.me_files
    }
  end

  @doc "Per-day counts (oldest first): asks, searches, capsules, suggestions, total."
  def daily(days) do
    Repo.all(
      from e in AccessEvent,
        where: e.occurred_at >= ^since(days),
        group_by: [
          fragment("date(?)", e.occurred_at),
          e.kind,
          fragment("?->>'form'", e.response_shape)
        ],
        select:
          {fragment("date(?)", e.occurred_at), e.kind, fragment("?->>'form'", e.response_shape),
           count(e.id)}
    )
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {day, rows} ->
      sum = fn pred -> rows |> Enum.filter(pred) |> Enum.map(&elem(&1, 3)) |> Enum.sum() end

      %{
        day: day,
        asks: sum.(fn {_, kind, form, _} -> kind == "oracle" and form != "search_traits" end),
        searches: sum.(fn {_, kind, form, _} -> kind == "oracle" and form == "search_traits" end),
        capsules: sum.(fn {_, kind, _, _} -> kind == "capsule" end),
        suggestions: sum.(fn {_, kind, _, _} -> kind == "suggestion" end),
        total: sum.(fn _ -> true end)
      }
    end)
    |> Enum.sort_by(& &1.day, Date)
  end

  @doc "Reads per assistant (client): events and distinct grants."
  def by_client(days) do
    Repo.all(
      from e in AccessEvent,
        join: g in Grant,
        on: g.id == e.mecp_grant_id,
        join: c in Client,
        on: c.id == g.mecp_client_id,
        where: e.occurred_at >= ^since(days),
        group_by: [c.id, c.name],
        order_by: [desc: count(e.id)],
        select: %{
          client: c.name,
          events: count(e.id),
          oracle: filter(count(e.id), e.kind == "oracle"),
          capsules: filter(count(e.id), e.kind == "capsule"),
          grants: count(e.mecp_grant_id, :distinct)
        }
    )
  end

  @doc "Existing traits assistants ask about most (`ask_me`), with distinct grants."
  def top_traits(days, limit \\ 15) do
    Repo.all(
      from e in AccessEvent,
        join: t in Trait,
        on: t.id == type(fragment("(?->>'trait_id')", e.response_shape), :integer),
        where:
          e.occurred_at >= ^since(days) and e.kind == "oracle" and
            fragment("?->>'form'", e.response_shape) != "search_traits",
        group_by: [t.id, t.trait_name],
        order_by: [desc: count(e.id), asc: t.trait_name],
        limit: ^limit,
        select: %{
          trait_id: t.id,
          trait: t.trait_name,
          asks: count(e.id),
          grants: count(e.mecp_grant_id, :distinct)
        }
    )
  end

  @doc "Suggestions filed in the window, by trait: filed, accepted, dismissed, pending, observed."
  def suggestions_by_trait(days, limit \\ 15) do
    Repo.all(
      from s in TagSuggestion,
        join: t in Trait,
        on: t.id == s.trait_id,
        where: s.inserted_at >= ^since(days),
        group_by: [t.id, t.trait_name],
        order_by: [desc: count(s.id), asc: t.trait_name],
        limit: ^limit,
        select: %{
          trait_id: t.id,
          trait: t.trait_name,
          filed: count(s.id),
          accepted: filter(count(s.id), s.status == "accepted"),
          dismissed: filter(count(s.id), s.status == "dismissed"),
          pending: filter(count(s.id), s.status == "pending"),
          observed: filter(count(s.id), s.source == "observed")
        }
    )
  end

  defp since(days), do: DateTime.add(DateTime.utc_now(), -days * 86_400)
end
