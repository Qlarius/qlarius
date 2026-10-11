defmodule Qlarius.YouData.TraitIntegrity do
  @moduledoc """
  Read-only catalog checks. Nothing here writes.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.Surveys.{Survey, SurveyAnswer, SurveyQuestion}
  alias Qlarius.YouData.TraitRelationships
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitRelationship

  @skip_names MapSet.new([
                "rather not say",
                "prefer not to say",
                "prefer not say",
                "decline"
              ])

  def report(opts \\ []) do
    threshold = Keyword.get(opts, :skip_rate_threshold, 0.15)
    counts = tag_counts()
    monitoring = skip_monitoring(threshold)

    issues =
      []
      |> Kernel.++(duplicate_skip_names(counts))
      |> Kernel.++(missing_skips(counts))
      |> Kernel.++(multiple_skips(counts))
      |> Kernel.++(skip_order(counts))
      |> Kernel.++(duplicate_orders(counts))
      |> Kernel.++(orphans(counts))
      |> Kernel.++(placeholder_names(counts))
      |> Kernel.++(missing_answers(counts))
      |> Kernel.++(legacy_wording(counts))
      |> Kernel.++(search_term_repeats_name(counts))
      |> Kernel.++(search_term_on_many_parents(counts))
      |> Kernel.++(relationship_issues(counts))
      |> Kernel.++(conflicting_rules(counts))
      |> Kernel.++(high_skip_rates(monitoring, counts))

    %{
      summary: summary(issues),
      skip_rate_threshold: threshold,
      skip_monitoring: monitoring,
      issues: issues
    }
  end

  defp summary(issues) do
    Enum.reduce(issues, %{}, fn issue, acc ->
      Map.update(acc, issue.check, 1, &(&1 + 1))
    end)
  end

  defp tag_counts do
    Repo.all(
      from mt in MeFileTag,
        join: t in Trait,
        on: mt.trait_id == t.id,
        group_by: fragment("coalesce(?, ?)", t.parent_trait_id, t.id),
        select: {fragment("coalesce(?, ?)", t.parent_trait_id, t.id), count(mt.id)}
    )
    |> Map.new()
  end

  defp duplicate_skip_names(counts) do
    flagged =
      Repo.all(
        from t in Trait,
          where:
            t.is_active == true and t.is_skipped_tag == true and not is_nil(t.parent_trait_id),
          select: t.parent_trait_id
      )

    Repo.all(
      from t in Trait,
        join: p in Trait,
        on: p.id == t.parent_trait_id,
        where:
          t.is_active == true and t.is_skipped_tag == false and t.parent_trait_id in ^flagged,
        select: %{
          id: t.id,
          name: t.trait_name,
          parent_id: p.id,
          parent_name: p.trait_name
        }
    )
    |> Enum.filter(&skip_like?(&1.name))
    |> Enum.map(fn row ->
      issue("duplicate_skip_name", row, counts, row.parent_id)
    end)
  end

  defp missing_skips(counts) do
    flagged =
      Repo.all(
        from t in Trait,
          where:
            t.is_active == true and t.is_skipped_tag == true and not is_nil(t.parent_trait_id),
          select: t.parent_trait_id
      )

    Repo.all(
      from p in Trait,
        where:
          is_nil(p.parent_trait_id) and p.is_active == true and p.skip_exempt == false and
            p.input_type != "single_select_zip" and p.id not in ^flagged,
        select: %{id: p.id, name: p.trait_name, parent_id: nil, parent_name: nil}
    )
    |> Enum.map(&issue("missing_skip", &1, counts, &1.id))
  end

  defp multiple_skips(counts) do
    Repo.all(
      from t in Trait,
        join: p in Trait,
        on: p.id == t.parent_trait_id,
        where: t.is_active == true and t.is_skipped_tag == true,
        group_by: [p.id, p.trait_name],
        having: count(t.id) > 1,
        select: %{id: p.id, name: p.trait_name, parent_id: p.id, parent_name: p.trait_name}
    )
    |> Enum.map(&issue("multiple_skips", &1, counts, &1.id))
  end

  defp skip_order(counts) do
    children =
      Repo.all(
        from t in Trait,
          join: p in Trait,
          on: p.id == t.parent_trait_id,
          where: t.is_active == true and not is_nil(t.parent_trait_id),
          order_by: [asc: t.display_order, asc: t.id],
          select: %{
            id: t.id,
            name: t.trait_name,
            parent_id: p.id,
            parent_name: p.trait_name,
            display_order: t.display_order,
            skip?: t.is_skipped_tag
          }
      )

    children
    |> Enum.group_by(& &1.parent_id)
    |> Enum.flat_map(fn {_parent_id, kids} ->
      case Enum.find(kids, & &1.skip?) do
        nil ->
          []

        skip ->
          if List.last(kids).id == skip.id do
            []
          else
            [issue("skip_not_last", skip, counts, skip.parent_id)]
          end
      end
    end)
  end

  defp duplicate_orders(counts) do
    Repo.all(
      from t in Trait,
        join: p in Trait,
        on: p.id == t.parent_trait_id,
        where: t.is_active == true and not is_nil(t.parent_trait_id),
        group_by: [p.id, p.trait_name, t.display_order],
        having: count(t.id) > 1,
        select: %{id: p.id, name: p.trait_name, parent_id: p.id, parent_name: p.trait_name}
    )
    |> Enum.uniq_by(& &1.id)
    |> Enum.map(&issue("duplicate_display_order", &1, counts, &1.id))
  end

  defp orphans(counts) do
    surveyed = Surveys.surveyed_trait_ids_query()

    Repo.all(
      from p in Trait,
        where:
          is_nil(p.parent_trait_id) and p.is_active == true and p.id not in subquery(surveyed),
        select: %{id: p.id, name: p.trait_name, parent_id: nil, parent_name: nil}
    )
    |> Enum.map(&issue("orphan_parent", &1, counts, &1.id))
  end

  defp placeholder_names(counts) do
    Repo.all(
      from t in Trait,
        where:
          t.is_active == true and
            (fragment("? ~* ?", t.trait_name, "(^|[^a-z])test([^a-z]|$)") or
               ilike(t.trait_name, "%placeholder%") or ilike(t.trait_name, "%lorem%")),
        select: %{
          id: t.id,
          name: t.trait_name,
          parent_id: t.parent_trait_id,
          parent_name: nil
        }
    )
    |> Enum.map(fn row ->
      issue("placeholder_name", row, counts, row.parent_id || row.id)
    end)
  end

  defp missing_answers(counts) do
    Repo.all(
      from c in Trait,
        join: p in Trait,
        on: p.id == c.parent_trait_id,
        join: q in SurveyQuestion,
        on: q.trait_id == p.id,
        left_join: a in SurveyAnswer,
        on: a.trait_id == c.id and a.survey_question_id == q.id,
        where:
          c.is_active == true and
            (is_nil(a.id) or is_nil(a.text) or fragment("btrim(?)", a.text) == ""),
        select: %{id: c.id, name: c.trait_name, parent_id: p.id, parent_name: p.trait_name}
    )
    |> Enum.map(&issue("missing_survey_answer", &1, counts, &1.parent_id))
  end

  defp legacy_wording(counts) do
    pattern = "click add/update|<br|  "

    questions =
      Repo.all(
        from q in SurveyQuestion,
          join: p in Trait,
          on: p.id == q.trait_id,
          where: fragment("? ~* ?", q.text, ^pattern),
          select: %{id: p.id, name: p.trait_name, parent_id: p.id, parent_name: p.trait_name}
      )

    answers =
      Repo.all(
        from a in SurveyAnswer,
          join: c in Trait,
          on: c.id == a.trait_id,
          join: p in Trait,
          on: p.id == c.parent_trait_id,
          where: fragment("? ~* ?", a.text, ^pattern),
          select: %{id: c.id, name: c.trait_name, parent_id: p.id, parent_name: p.trait_name}
      )

    (questions ++ answers)
    |> Enum.uniq_by(& &1.id)
    |> Enum.map(&issue("legacy_wording", &1, counts, &1.parent_id))
  end

  defp search_term_repeats_name(counts) do
    Repo.all(
      from t in Trait,
        where:
          t.is_active == true and
            fragment(
              "EXISTS (SELECT 1 FROM unnest(?) AS term WHERE lower(term) = lower(?))",
              t.search_terms,
              t.trait_name
            ),
        select: %{
          id: t.id,
          name: t.trait_name,
          parent_id: t.parent_trait_id,
          parent_name: nil
        }
    )
    |> Enum.map(fn row ->
      issue("search_term_repeats_name", row, counts, row.parent_id || row.id)
    end)
  end

  defp search_term_on_many_parents(counts) do
    parents =
      Repo.all(
        from t in Trait,
          where: is_nil(t.parent_trait_id) and t.is_active == true and t.search_terms != [],
          select: %{id: t.id, name: t.trait_name, terms: t.search_terms}
      )

    overused =
      parents
      |> Enum.flat_map(fn parent ->
        Enum.map(parent.terms || [], &{String.downcase(&1), parent})
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_term, group} -> length(group) > 3 end)

    Enum.flat_map(overused, fn {term, group} ->
      Enum.map(group, fn parent ->
        issue(
          "search_term_on_many_parents",
          %{id: parent.id, name: parent.name, parent_id: parent.id, parent_name: parent.name},
          counts,
          parent.id
        )
        |> Map.put(:detail, "#{term} is on #{length(group)} parents")
      end)
    end)
  end

  defp relationship_issues(counts) do
    Repo.all(TraitRelationship)
    |> Enum.flat_map(fn relationship ->
      relationship = Repo.preload(relationship, [:trait, :related_trait])

      Enum.map(TraitRelationships.warnings(relationship), fn warning ->
        trait = relationship.trait

        issue(
          "relationship_warning",
          %{
            id: trait.id,
            name: trait.trait_name,
            parent_id: trait.parent_trait_id,
            parent_name: nil
          },
          counts,
          trait.parent_trait_id || trait.id
        )
        |> Map.put(:detail, warning)
        |> Map.put(:relationship_id, relationship.id)
      end)
    end)
  end

  defp conflicting_rules(counts) do
    Repo.all(
      from t in Trait,
        where:
          (not is_nil(t.ideal_min_tags) and not is_nil(t.ideal_max_tags) and
             t.ideal_min_tags > t.ideal_max_tags) or
            (not is_nil(t.ideal_max_tags) and not is_nil(t.hard_max_tags) and
               t.ideal_max_tags > t.hard_max_tags) or
            (not is_nil(t.ideal_min_tags) and not is_nil(t.hard_max_tags) and
               t.ideal_min_tags > t.hard_max_tags) or
            (not is_nil(t.unripe_days) and not is_nil(t.ripen_days) and
               t.unripe_days > t.ripen_days) or
            (not is_nil(t.stale_days) and not is_nil(t.expired_days) and
               t.stale_days > t.expired_days) or
            (not is_nil(t.ripen_days) and not is_nil(t.stale_days) and
               t.ripen_days >= t.stale_days) or
            (not is_nil(t.parent_trait_id) and
               (not is_nil(t.ideal_min_tags) or not is_nil(t.ideal_max_tags) or
                  not is_nil(t.hard_max_tags))) or
            (is_nil(t.parent_trait_id) and t.input_type != "multi_select" and
               (not is_nil(t.ideal_min_tags) or not is_nil(t.ideal_max_tags) or
                  not is_nil(t.hard_max_tags))),
        select: %{
          id: t.id,
          name: t.trait_name,
          parent_id: t.parent_trait_id,
          parent_name: nil
        }
    )
    |> Enum.map(fn row ->
      issue("conflicting_rules", row, counts, row.parent_id || row.id)
    end)
  end

  defp high_skip_rates(monitoring, counts) do
    monitoring
    |> Enum.filter(& &1.review_wording)
    |> Enum.map(fn row ->
      issue(
        "high_skip_rate",
        %{id: row.parent_id, name: row.parent_name, parent_id: row.parent_id, parent_name: row.parent_name},
        counts,
        row.parent_id
      )
      |> Map.put(:skip_rate, row.skip_rate)
    end)
  end

  defp skip_monitoring(threshold) do
    now = DateTime.utc_now()
    ago_30 = DateTime.add(now, -30, :day)
    ago_90 = DateTime.add(now, -90, :day)
    surveys = survey_names()
    recent_30 = recent_skips(ago_30)
    recent_90 = recent_skips(ago_90)

    Repo.all(
      from p in Trait,
        join: c in Trait,
        on: c.parent_trait_id == p.id,
        join: mt in MeFileTag,
        on: mt.trait_id == c.id,
        where: is_nil(p.parent_trait_id),
        group_by: [p.id, p.trait_name],
        select: %{
          parent_id: p.id,
          parent_name: p.trait_name,
          answered: count(mt.me_file_id, :distinct),
          skips: filter(count(mt.me_file_id, :distinct), c.is_skipped_tag == true)
        }
    )
    |> Enum.map(fn row ->
      rate = if row.answered > 0, do: row.skips / row.answered, else: 0.0

      %{
        parent_id: row.parent_id,
        parent_name: row.parent_name,
        skip_count: row.skips,
        answered_count: row.answered,
        skip_rate: rate,
        skips_30_days: Map.get(recent_30, row.parent_id, 0),
        skips_90_days: Map.get(recent_90, row.parent_id, 0),
        survey: Map.get(surveys, row.parent_id),
        review_wording: rate > threshold
      }
    end)
    |> Enum.sort_by(& &1.skip_rate, :desc)
  end

  defp recent_skips(%DateTime{} = since) do
    naive = DateTime.to_naive(since)

    Repo.all(
      from p in Trait,
        join: c in Trait,
        on: c.parent_trait_id == p.id,
        join: mt in MeFileTag,
        on: mt.trait_id == c.id,
        where: c.is_skipped_tag == true and mt.added_date >= ^naive,
        group_by: p.id,
        select: {p.id, count(mt.me_file_id, :distinct)}
    )
    |> Map.new()
  end

  defp survey_names do
    Repo.all(
      from p in Trait,
        join: sq in SurveyQuestion,
        on: sq.trait_id == p.id,
        join: sqs in "survey_question_surveys",
        on: sqs.survey_question_id == sq.id,
        join: s in Survey,
        on: s.id == sqs.survey_id,
        where: s.active == true,
        group_by: p.id,
        select: {p.id, min(s.name)}
    )
    |> Map.new()
  end

  defp skip_like?(name) when is_binary(name) do
    normalized =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z\s]/u, "")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    MapSet.member?(@skip_names, normalized)
  end

  defp skip_like?(_), do: false

  defp issue(check, row, counts, count_id) do
    %{
      check: check,
      severity: "warning",
      trait_id: row.id,
      trait_name: row.name,
      parent_trait_id: row.parent_id,
      parent_trait_name: row.parent_name,
      tag_count: Map.get(counts, count_id, 0)
    }
  end
end
