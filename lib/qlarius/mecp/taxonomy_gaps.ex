defmodule Qlarius.MeCP.TaxonomyGaps do
  @moduledoc """
  Taxonomy-gap signals: what assistants ask about that the trait taxonomy
  doesn't cover, so admins can see which trait sets are worth adding.

  Recorded at the oracle's miss points:

    * `search_traits` finds nothing (`no_match`), or only category-name hits
      (`weak_match`, with the nearest trait)
    * `ask_me` names a trait that doesn't exist (`unknown_trait`)
    * `suggest_tag` names a trait that doesn't exist (`unknown_trait`) or one
      in no active survey (`not_askable`, an orphaned trait people still want)

  `orphan_demand/1` also counts suggestions already filed on orphaned traits,
  so demand from before capture began still shows.

  De-identified, per the owner's choice (MeCP otherwise stores no content):

    * no person, grant or MeFile link: `person_key` is a keyed one-way hash
      of the MeFile id, used only to count distinct people
    * day granularity only, no timestamps, so rows can't be joined back to
      access events by time
    * subject text is trimmed, length-capped and scrubbed of emails, links and
      long digit runs; the assistant's `reason` is never stored
    * the admin list defaults to subjects `min_people/0` (3) different people
      raised; admins can widen it to All or narrow it to 10+

  It is de-identified, not anonymous: someone holding the server secret could
  re-derive person keys. Recording is best-effort and can never fail the read
  that triggered it.
  """

  import Ecto.Query

  alias Qlarius.MeCP
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.Keys
  alias Qlarius.MeCP.Suggestions.TagSuggestion
  alias Qlarius.MeCP.TaxonomyGaps.Gap
  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.Traits.Trait

  @min_people 3
  @subject_max 160
  @max_values 5
  @value_max 60

  @doc "Default minimum of distinct people for the admin gap list."
  def min_people, do: @min_people

  # --- capture -------------------------------------------------------------------

  @doc """
  Records one gap signal for the grant's (effective) MeFile. Options:
  `:nearest_trait_id`, `:proposed_values`, `:now`.

  Returns `:ok` (recorded, or already recorded today) or `:skipped`.
  """
  def record(%Grant{} = grant, source, reason, subject, opts \\ []) do
    with true <- source in Gap.sources() and reason in Gap.reasons(),
         {:ok, text, key} <- normalize(subject) do
      now = Keyword.get(opts, :now, DateTime.utc_now())

      %Gap{
        source: source,
        reason: reason,
        subject: text,
        subject_key: key,
        nearest_trait_id: Keyword.get(opts, :nearest_trait_id),
        proposed_values: clean_values(Keyword.get(opts, :proposed_values, [])),
        mecp_client_id: grant.mecp_client_id,
        person_key: person_key(MeCP.effective_me_file_id(grant)),
        occurred_on: DateTime.to_date(now)
      }
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:subject_key, :person_key, :occurred_on, :source]
      )

      :ok
    else
      _ -> :skipped
    end
  rescue
    # Best-effort: a gap note must never break the oracle read behind it
    _ -> :skipped
  end

  @doc false
  def person_key(me_file_id), do: Keys.hmac("taxonomy-gap-person", to_string(me_file_id))

  @doc """
  Display text and grouping key for a subject, or `:error` when nothing
  meaningful is left. The key is lowercase words only, so "Anime?" and
  "anime" group together.
  """
  def normalize(subject) when is_binary(subject) do
    text =
      subject
      |> scrub()
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()
      |> String.slice(0, @subject_max)

    key =
      text
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\p{N}\s]+/u, " ")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if String.length(key) >= 3, do: {:ok, text, key}, else: :error
  end

  def normalize(_), do: :error

  defp scrub(text) do
    text
    |> String.replace(~r/\S+@\S+\.\S+/u, "[email]")
    |> String.replace(~r/https?:\/\/\S+/iu, "[link]")
    |> String.replace(~r/\d{4,}/u, "#")
  end

  defp clean_values(values) do
    values
    |> List.wrap()
    |> Enum.flat_map(fn
      value when is_binary(value) ->
        case value |> scrub() |> String.trim() |> String.slice(0, @value_max) do
          "" -> []
          cleaned -> [cleaned]
        end

      _ ->
        []
    end)
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.take(@max_values)
  end

  # --- admin read model -----------------------------------------------------------

  @doc """
  Subjects raised in the last `days` by at least `min_people/0` different
  people, most people first. Each row: subject (the most common wording),
  subject_key, people, mentions, sources, reasons, nearest trait name,
  values mentioned, first and last day seen.
  """
  def list_subjects(days, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    min_people = Keyword.get(opts, :min_people, @min_people)
    since = since(days)

    rows =
      Repo.all(
        from g in Gap,
          where: g.occurred_on >= ^since,
          group_by: g.subject_key,
          having: count(g.person_key, :distinct) >= ^min_people,
          order_by: [desc: count(g.person_key, :distinct), desc: count(g.id)],
          limit: ^limit,
          select: %{
            subject_key: g.subject_key,
            subject: fragment("mode() WITHIN GROUP (ORDER BY ?)", g.subject),
            people: count(g.person_key, :distinct),
            mentions: count(g.id),
            sources: fragment("array_agg(DISTINCT ?)", g.source),
            reasons: fragment("array_agg(DISTINCT ?)", g.reason),
            nearest_trait_id: fragment("mode() WITHIN GROUP (ORDER BY ?)", g.nearest_trait_id),
            first_seen: min(g.occurred_on),
            last_seen: max(g.occurred_on)
          }
      )

    rows
    |> attach_trait_names()
    |> attach_values(since)
  end

  @doc "How many subjects in the window are below the people threshold (not shown)."
  def hidden_subject_count(days, opts \\ []) do
    min_people = Keyword.get(opts, :min_people, @min_people)

    Repo.one(
      from s in subquery(
             from g in Gap,
               where: g.occurred_on >= ^since(days),
               group_by: g.subject_key,
               having: count(g.person_key, :distinct) < ^min_people,
               select: %{key: g.subject_key}
           ),
           select: count(s.key)
    )
  end

  @doc """
  Orphaned traits (in no active survey) that assistants still want: trait
  name, people, mentions, last day seen. Counts two signals:

    * `not_askable` gaps: a suggestion refused because the trait is orphaned
    * suggestions already filed on the trait, in any status, from before it
      was orphaned or before the orphan rule (they stay in the queue, hidden
      from the owner)

  A trait put back in an active survey drops out. Trait names are the
  system's own vocabulary, so these show without a people threshold.
  """
  def orphan_demand(days) do
    since = since(days)

    refused =
      Repo.all(
        from g in Gap,
          as: :row,
          join: t in Trait,
          on: t.id == g.nearest_trait_id,
          where: g.occurred_on >= ^since and g.reason == "not_askable",
          where: not exists(surveyed(:nearest_trait_id)),
          select: {t.id, t.trait_name, g.person_key, g.occurred_on}
      )

    filed =
      Repo.all(
        from s in TagSuggestion,
          as: :row,
          join: t in Trait,
          on: t.id == s.trait_id,
          where: s.inserted_at >= ^DateTime.new!(since, ~T[00:00:00]),
          where: not exists(surveyed(:trait_id)),
          select: {t.id, t.trait_name, s.me_file_id, s.inserted_at}
      )
      # Same keyed hash as gaps, so one person counts once across both
      |> Enum.map(fn {id, name, me_file_id, at} ->
        {id, name, person_key(me_file_id), DateTime.to_date(at)}
      end)

    (refused ++ filed)
    |> Enum.group_by(fn {id, name, _, _} -> {id, name} end)
    |> Enum.map(fn {{id, name}, hits} ->
      %{
        trait_id: id,
        trait: name,
        people: hits |> Enum.uniq_by(&elem(&1, 2)) |> length(),
        mentions: length(hits),
        last_seen: hits |> Enum.map(&elem(&1, 3)) |> Enum.max(Date)
      }
    end)
    |> Enum.sort_by(&{-&1.people, &1.trait})
  end

  # Whether the outer row's trait is in an active survey. EXISTS rather than
  # NOT IN, which matches nothing once any survey question has a null trait.
  defp surveyed(field) do
    from sq in Surveys.surveyed_trait_ids_query(),
      where: sq.trait_id == field(parent_as(:row), ^field)
  end

  defp attach_trait_names(rows) do
    ids = rows |> Enum.map(& &1.nearest_trait_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    names =
      Repo.all(from t in Trait, where: t.id in ^ids, select: {t.id, t.trait_name}) |> Map.new()

    Enum.map(rows, &Map.put(&1, :nearest_trait, names[&1.nearest_trait_id]))
  end

  # The values assistants proposed for each shown subject, most mentioned first
  defp attach_values(rows, since) do
    keys = Enum.map(rows, & &1.subject_key)

    values_by_key =
      Repo.all(
        from g in Gap,
          where: g.subject_key in ^keys and g.occurred_on >= ^since,
          select: {g.subject_key, g.proposed_values}
      )
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {key, lists} ->
        top =
          lists
          |> List.flatten()
          |> Enum.frequencies_by(&String.downcase/1)
          |> Enum.sort_by(fn {value, n} -> {-n, value} end)
          |> Enum.take(@max_values)
          |> Enum.map(&elem(&1, 0))

        {key, top}
      end)

    Enum.map(rows, &Map.put(&1, :values, Map.get(values_by_key, &1.subject_key, [])))
  end

  defp since(days), do: Date.add(Date.utc_today(), -days)
end
