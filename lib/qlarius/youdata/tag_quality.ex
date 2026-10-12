defmodule Qlarius.YouData.TagQuality do
  @moduledoc """
  Green, yellow, or red for each tagged parent on a MeFile.

  A tag with values is green unless a count, freshness, or consistency rule
  is broken. A tag that is not ripe yet stays green and says some marketers
  will wait. A parent whose only value is a skip is neutral. A parent with
  no tags is absent, so its hole stays plain. Birthdate is not a trait:
  when the MeFile has a date of birth, parent id -1 is always green.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.QualityConfirmations
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitRelationship

  @not_ripe "Some marketers will wait until this is ripe before they target it."

  def for_me_file(me_file_id, now \\ DateTime.utc_now()) do
    rows = tag_rows(me_file_id)
    by_parent = Enum.group_by(rows, & &1.parent_id)
    parent_ids = Map.keys(by_parent)
    parents = parent_rules(parent_ids)
    today = DateTime.to_date(now)

    presence = presence(rows)
    child_owner = Map.new(rows, &{&1.trait_id, &1.parent_id})
    relationships = relationships(MapSet.to_list(presence) ++ parent_ids)
    names = names_for(relationships, parents, rows)
    confirmed = QualityConfirmations.prepare(me_file_id, now)

    Enum.reduce(by_parent, %{}, fn {parent_id, parent_rows}, acc ->
      parent = Map.get(parents, parent_id)

      if parent do
        reasons =
          []
          |> maybe(
            fn parent, rows -> count_reason(parent, rows, confirmed.counts) end,
            parent,
            parent_rows
          )
          |> maybe(&freshness_reason/3, parent, parent_rows, today)
          |> maybe(&exclusive_mix_reason/1, parent_rows)
          |> Kernel.++(
            consistency_reasons(
              parent_id,
              relationships,
              presence,
              child_owner,
              names,
              confirmed.conflicts
            )
          )
          |> collapse_confirmed()

        Map.put(acc, parent_id, %{status: status(reasons, parent_rows), reasons: reasons})
      else
        acc
      end
    end)
    |> put_birthdate(me_file_id)
  end

  defp put_birthdate(quality, me_file_id) do
    born? =
      Repo.exists?(
        from m in MeFile,
          where: m.id == ^me_file_id and not is_nil(m.date_of_birth)
      )

    if born?, do: Map.put(quality, -1, %{status: :green, reasons: []}), else: quality
  end

  defp maybe(reasons, fun, rows) do
    case fun.(rows) do
      nil -> reasons
      reason -> [reason | reasons]
    end
  end

  defp maybe(reasons, fun, a, b) do
    case fun.(a, b) do
      nil -> reasons
      reason -> [reason | reasons]
    end
  end

  defp maybe(reasons, fun, a, b, c) do
    case fun.(a, b, c) do
      nil -> reasons
      reason -> [reason | reasons]
    end
  end

  defp tag_rows(me_file_id) do
    Repo.all(
      from mt in MeFileTag,
        join: t in Trait,
        on: mt.trait_id == t.id,
        where: mt.me_file_id == ^me_file_id,
        select: %{
          trait_id: t.id,
          parent_id: coalesce(t.parent_trait_id, t.id),
          name: t.trait_name,
          skip?: t.is_skipped_tag,
          exclusive?: t.is_exclusive or t.is_skipped_tag,
          added_date: mt.added_date
        }
    )
  end

  defp parent_rules([]), do: %{}

  defp parent_rules(parent_ids) do
    Repo.all(
      from t in Trait,
        where: t.id in ^parent_ids,
        select: %{
          id: t.id,
          name: t.trait_name,
          input_type: t.input_type,
          ideal_min_tags: t.ideal_min_tags,
          ideal_max_tags: t.ideal_max_tags,
          hard_max_tags: t.hard_max_tags,
          unripe_days: t.unripe_days,
          ripen_days: t.ripen_days,
          stale_days: t.stale_days,
          expired_days: t.expired_days
        }
    )
    |> Map.new(&{&1.id, &1})
  end

  defp presence(rows) do
    Enum.reduce(rows, MapSet.new(), fn row, set ->
      if row.skip? do
        set
      else
        set |> MapSet.put(row.trait_id) |> MapSet.put(row.parent_id)
      end
    end)
  end

  defp relationships([]), do: []

  defp relationships(ids) do
    ids = Enum.uniq(ids)

    Repo.all(
      from r in TraitRelationship,
        where: r.trait_id in ^ids or r.related_trait_id in ^ids
    )
  end

  defp names_for(relationships, parents, rows) do
    known =
      Map.merge(
        Map.new(parents, fn {id, parent} -> {id, parent.name} end),
        Map.new(rows, &{&1.trait_id, &1.name})
      )

    missing =
      relationships
      |> Enum.flat_map(&[&1.trait_id, &1.related_trait_id])
      |> Enum.uniq()
      |> Enum.reject(&Map.has_key?(known, &1))

    extra =
      if missing == [] do
        %{}
      else
        Repo.all(from t in Trait, where: t.id in ^missing, select: {t.id, t.trait_name})
        |> Map.new()
      end

    Map.merge(known, extra)
  end

  defp count_reason(parent, rows, confirmed_counts) do
    values = Enum.reject(rows, & &1.skip?)

    cond do
      parent.input_type != "multi_select" ->
        nil

      values == [] ->
        nil

      parent.ideal_min_tags == nil and parent.ideal_max_tags == nil and
          parent.hard_max_tags == nil ->
        nil

      true ->
        case count_band(parent, length(values)) do
          %{confirmable: true} = reason ->
            case Map.get(confirmed_counts, parent.id) do
              %DateTime{} = confirmed_at -> confirmed_reason(reason, confirmed_at)
              _ -> reason
            end

          other ->
            other
        end
    end
  end

  defp count_band(parent, count) do
    min = parent.ideal_min_tags
    max = parent.ideal_max_tags
    hard = parent.hard_max_tags

    cond do
      hard != nil and count > hard ->
        reason(:red, :count, too_many_text(min, max, hard), %{confirmable: true})

      max != nil and count > max ->
        reason(:yellow, :count, fewer_text(min, max), %{confirmable: true})

      min != nil and count < min ->
        reason(:yellow, :count, "Fewer than usual")

      true ->
        nil
    end
  end

  defp fewer_text(min, max) do
    "For best results, consider selecting fewer tag values." <> sweet_spot_sentence(min, max)
  end

  defp sweet_spot_sentence(min, max) when is_integer(min) and is_integer(max) do
    " Recommended sweet spot is #{min}-#{max}, but personal accuracy is more important: confirm if accurate as is."
  end

  defp sweet_spot_sentence(_, _), do: ""

  defp too_many_text(min, max, hard) do
    range =
      cond do
        min != nil and max != nil ->
          " Try to stay between #{min} and #{max} tag values."

        max != nil ->
          " Try to stay at #{max} or fewer tag values."

        hard != nil ->
          " Try to stay at #{hard} or fewer tag values."

        true ->
          ""
      end

    "Too many selected. Advertisers will likely suspect and exclude." <> range <>
      sweet_spot_sentence(min, max)
  end

  defp exclusive_mix_reason(rows) do
    if Enum.any?(rows, & &1.exclusive?) and Enum.any?(rows, &(not &1.exclusive?)) do
      reason(:yellow, :exclusive, "exclusive answer combined with other answers")
    end
  end

  defp freshness_reason(parent, rows, today) do
    case latest_added(rows) do
      %NaiveDateTime{} = added ->
        age = Date.diff(today, NaiveDateTime.to_date(added))
        freshness_band(parent, age)

      _ ->
        nil
    end
  end

  defp latest_added(rows) do
    rows
    |> Enum.map(& &1.added_date)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      dates -> Enum.max(dates)
    end
  end

  defp freshness_band(parent, age) do
    cond do
      parent.unripe_days == nil and parent.ripen_days == nil and parent.stale_days == nil and
          parent.expired_days == nil ->
        nil

      parent.unripe_days != nil and age < parent.unripe_days ->
        reason(:green, :unripe, @not_ripe)

      parent.ripen_days != nil and age < parent.ripen_days ->
        reason(:green, :ripen, @not_ripe)

      parent.expired_days != nil and age > parent.expired_days ->
        reason(:red, :expired, "Out of date. Saving confirms these values.")

      parent.stale_days != nil and age > parent.stale_days ->
        reason(:yellow, :stale, "Due for a review. Saving confirms these values.")

      true ->
        nil
    end
  end

  defp consistency_reasons(parent_id, relationships, presence, child_owner, names, confirmed) do
    Enum.flat_map(relationships, fn relationship ->
      case relationship.kind do
        "conflicts" ->
          conflict_reasons(parent_id, relationship, presence, child_owner, names, confirmed)

        "requires" ->
          require_reasons(parent_id, relationship, presence, child_owner, names)

        _ ->
          []
      end
    end)
  end

  defp conflict_reasons(parent_id, relationship, presence, child_owner, names, confirmed) do
    left = relationship.trait_id
    right = relationship.related_trait_id

    if present?(left, presence) and present?(right, presence) do
      owners = [owner(left, child_owner), owner(right, child_owner)]

      if parent_id in owners do
        other = if owner(left, child_owner) == parent_id, do: right, else: left
        local = if other == right, do: left, else: right

        reason = %{
          status: if(relationship.severity == "soft", do: :yellow, else: :red),
          check: :conflict,
          text: conflict_text(relationship, names, parent_id, local, other),
          tag: tag_side(other, child_owner, names),
          relationship_id: relationship.id,
          confirmable: true
        }

        case Map.get(confirmed, relationship.id) do
          %DateTime{} = confirmed_at -> [confirmed_reason(reason, confirmed_at)]
          _ -> [reason]
        end
      else
        []
      end
    else
      []
    end
  end

  defp require_reasons(parent_id, relationship, presence, child_owner, names) do
    needed = relationship.trait_id
    other = relationship.related_trait_id

    if present?(needed, presence) and not present?(other, presence) and
         owner(needed, child_owner) == parent_id do
      [reason(:yellow, :requires, require_text(relationship, names, other))]
    else
      []
    end
  end

  defp present?(id, presence), do: MapSet.member?(presence, id)

  defp owner(id, child_owner), do: Map.get(child_owner, id, id)

  defp tag_side(id, child_owner, names) do
    parent_id = owner(id, child_owner)

    if parent_id == id do
      %{parent_id: id, parent: Map.get(names, id, "Tag"), value: nil}
    else
      %{
        parent_id: parent_id,
        parent: Map.get(names, parent_id, "Tag"),
        value: Map.get(names, id, "Tag")
      }
    end
  end

  defp conflict_text(%{note: note}, _names, _parent_id, _local_id, _other_id)
       when is_binary(note) and note != "",
       do: rephrase_combination(note)

  defp conflict_text(%{severity: "soft"}, names, parent_id, local_id, other_id) do
    other = Map.get(names, other_id, "another tag")

    subject =
      if local_id == parent_id do
        Map.get(names, parent_id, "Tag")
      else
        "#{Map.get(names, local_id, "Tag")} (#{Map.get(names, parent_id, "Tag")})"
      end

    "#{subject} is unusual with #{other}. Keep both if accurate."
  end

  defp conflict_text(_relationship, names, _parent_id, _local_id, other_id) do
    "Conflicts with #{Map.get(names, other_id, "another tag")}"
  end

  # Catalog notes are stored as "{a} can't be combined with {b}."
  # The sheet reads "{a} combined with {b} does not make sense."
  defp rephrase_combination(note) do
    case String.replace(note, "can't be combined with", "combined with", global: false) do
      ^note ->
        note

      rephrased ->
        if String.ends_with?(rephrased, ".") do
          String.replace_suffix(rephrased, ".", " does not make sense.")
        else
          rephrased <> " does not make sense."
        end
    end
  end

  defp require_text(%{note: note}, _names, _other) when is_binary(note) and note != "", do: note

  defp require_text(_relationship, names, other_id) do
    "Usually comes with #{Map.get(names, other_id, "another tag")}"
  end

  defp reason(status, check, text, extra \\ %{}) do
    Map.merge(%{status: status, check: check, text: text}, extra)
  end

  # Keep the warning they already read. Green and :confirmed stop it from
  # coloring the tag, and the edit sheet can still show the sentence.
  # withdraw_ids lets that sheet delete the override without a save.
  defp confirmed_reason(reason, confirmed_at) do
    id = Map.get(reason, :relationship_id)

    reason
    |> Map.drop([:confirmable, :tag, :relationship_id])
    |> Map.merge(%{
      status: :green,
      check: :confirmed,
      confirmed_at: confirmed_at,
      withdraw_kind: if(reason.check == :count, do: "count", else: "conflict"),
      withdraw_ids: if(is_integer(id), do: [id], else: [])
    })
  end

  defp collapse_confirmed(reasons) do
    Enum.reduce(reasons, [], fn
      %{check: :confirmed, text: text} = reason, acc ->
        case Enum.split_while(acc, &(!match?(%{check: :confirmed, text: ^text}, &1))) do
          {head, [existing | tail]} ->
            merged =
              %{existing | withdraw_ids: Enum.uniq(existing.withdraw_ids ++ reason.withdraw_ids)}

            head ++ [merged | tail]

          {_, []} ->
            acc ++ [reason]
        end

      reason, acc ->
        acc ++ [reason]
    end)
  end

  defp status(reasons, rows) do
    case worst(reasons) do
      :green -> if skip_only?(rows), do: :skipped, else: :green
      other -> other
    end
  end

  defp skip_only?(rows), do: rows != [] and Enum.all?(rows, & &1.skip?)

  defp worst([]), do: :green

  defp worst(reasons) do
    reasons
    |> Enum.map(& &1.status)
    |> Enum.max_by(&status_rank/1)
  end

  defp status_rank(:red), do: 2
  defp status_rank(:yellow), do: 1
  defp status_rank(:green), do: 0
end
